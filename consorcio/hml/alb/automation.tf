resource "aws_sns_topic" "alerts" { name = "${var.name}-alerts" }

resource "aws_ssm_document" "role" {
  name          = "${var.name}-role"
  document_type = "Command"
  content = jsonencode({
    schemaVersion = "2.2"
    description   = "Controla apenas componentes explicitamente listados do IIS APIs"
    parameters    = { Role = { type = "String", allowedValues = ["active", "standby"], interpolationType = "ENV_VAR" } }
    mainSteps = [{
      action = "aws:runPowerShellScript"
      name   = "SetRole"
      inputs = { timeoutSeconds = "90", runCommand = [templatefile("${path.module}/role.ps1.tftpl", {
        config = base64encode(jsonencode({ pool = var.pool_name, services = var.services, tasks = var.scheduled_tasks }))
      })] }
    }]
  })
}

resource "aws_cloudwatch_log_group" "worker" {
  name              = "/aws/lambda/${var.name}"
  retention_in_days = 30
}

resource "aws_lambda_function" "worker" {
  function_name    = var.name
  role             = aws_iam_role.worker.arn
  runtime          = "python3.12"
  handler          = "worker.handler"
  timeout          = 180
  filename         = data.archive_file.worker.output_path
  source_code_hash = data.archive_file.worker.output_base64sha256
  environment {
    variables = {
      TABLE          = aws_dynamodb_table.state.name
      INSTANCES      = jsonencode(var.instance_ids)
      GROUPS         = jsonencode({ for k, v in aws_lb_target_group.web : k => v.arn })
      LISTENER       = aws_lb_listener.https.arn
      DOCUMENT       = aws_ssm_document.role.name
      TOPIC          = aws_sns_topic.alerts.arn
      MACHINE        = "${local.prefix}:states:${var.region}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.name}"
      ENABLED        = tostring(var.enable_automatic_failover)
      PREPARED       = tostring(var.standby_prepared)
      ACCEPT_OVERLAP = tostring(var.accept_overlap_risk)
    }
  }
  depends_on = [aws_iam_role_policy.worker]
}

resource "aws_sfn_state_machine" "failover" {
  name     = var.name
  role_arn = aws_iam_role.flow.arn
  definition = jsonencode({
    StartAt        = "Claim"
    TimeoutSeconds = 600
    States = {
      Claim   = { Type = "Task", Resource = aws_lambda_function.worker.arn, Parameters = { action = "claim", "request.$" = "$", "owner.$" = "$$.Execution.Id" }, Next = "Stop" }
      Stop    = { Type = "Task", Resource = aws_lambda_function.worker.arn, Parameters = { action = "stop", "request.$" = "$" }, Next = "Wait180", Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "Block" }] }
      Wait180 = { Type = "Wait", Seconds = 180, Next = "Promote" }
      Promote = { Type = "Task", Resource = aws_lambda_function.worker.arn, Parameters = { action = "promote", "request.$" = "$" }, End = true, Catch = [{ ErrorEquals = ["States.ALL"], ResultPath = "$.error", Next = "Block" }] }
      Block   = { Type = "Task", Resource = aws_lambda_function.worker.arn, Parameters = { action = "block", "request.$" = "$" }, Next = "Failed" }
      Failed  = { Type = "Fail", Error = "FailoverBlocked", Cause = "Inspecionar estado e SNS; sem rollback automatico." }
    }
  })
}

resource "aws_cloudwatch_event_rule" "monitor" {
  name                = "${var.name}-monitor"
  schedule_expression = "rate(1 minute)"
}

resource "aws_cloudwatch_event_target" "monitor" {
  rule  = aws_cloudwatch_event_rule.monitor.name
  arn   = aws_lambda_function.worker.arn
  input = jsonencode({ action = "monitor" })
}

resource "aws_lambda_permission" "monitor" {
  statement_id  = "EventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.worker.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.monitor.arn
}

resource "aws_cloudwatch_metric_alarm" "worker_errors" {
  alarm_name          = "${var.name}-automation-errors"
  namespace           = "AWS/Lambda"
  metric_name         = "Errors"
  statistic           = "Sum"
  period              = 60
  evaluation_periods  = 1
  threshold           = 1
  comparison_operator = "GreaterThanOrEqualToThreshold"
  treat_missing_data  = "notBreaching"
  dimensions          = { FunctionName = aws_lambda_function.worker.function_name }
  alarm_actions       = [aws_sns_topic.alerts.arn]
}
