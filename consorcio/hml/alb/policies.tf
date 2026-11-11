resource "aws_iam_role_policy" "worker" {
  role = aws_iam_role.worker.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [
    { Effect = "Allow", Action = ["ec2:DescribeInstances", "ec2:DescribeInstanceStatus", "ssm:GetCommandInvocation", "ssm:DescribeInstanceInformation", "elasticloadbalancing:DescribeTargetHealth"], Resource = "*" },
    { Effect = "Allow", Action = ["ec2:StopInstances"], Resource = local.instance_arns },
    { Effect = "Allow", Action = ["ssm:SendCommand"], Resource = concat(local.instance_arns, [aws_ssm_document.role.arn]) },
    { Effect = "Allow", Action = ["elasticloadbalancing:ModifyListener"], Resource = aws_lb_listener.https.arn },
    { Effect = "Allow", Action = ["dynamodb:GetItem", "dynamodb:PutItem", "dynamodb:UpdateItem"], Resource = aws_dynamodb_table.state.arn },
    { Effect = "Allow", Action = ["sns:Publish"], Resource = aws_sns_topic.alerts.arn },
    { Effect = "Allow", Action = ["states:StartExecution"], Resource = "${local.prefix}:states:${var.region}:${data.aws_caller_identity.current.account_id}:stateMachine:${var.name}" },
    { Effect = "Allow", Action = ["logs:CreateLogStream", "logs:PutLogEvents"], Resource = "${aws_cloudwatch_log_group.worker.arn}:*" }
  ] })
}

resource "aws_iam_role_policy" "flow" {
  role   = aws_iam_role.flow.id
  policy = jsonencode({ Version = "2012-10-17", Statement = [{ Effect = "Allow", Action = "lambda:InvokeFunction", Resource = aws_lambda_function.worker.arn }] })
}
