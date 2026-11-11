output "alb_dns_name" { value = aws_lb.api.dns_name }

output "state_machine_arn" { value = aws_sfn_state_machine.failover.arn }

output "state_table" { value = aws_dynamodb_table.state.name }

output "role_document" { value = aws_ssm_document.role.name }

output "alerts_topic_arn" { value = aws_sns_topic.alerts.arn }
