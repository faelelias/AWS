output "image_builder_id" {
  description = "ID do Image Builder criado"
  value       = aws_appstream_image_builder.windows_builder.id
}

output "fleet_id" {
  description = "ID do Fleet criado"
  value       = aws_appstream_fleet.windows_fleet.id
}

output "stack_id" {
  description = "ID do Stack criado"
  value       = aws_appstream_stack.windows_stack.id
}

output "security_group_id" {
  description = "ID do Security Group criado"
  value       = aws_security_group.appstream.id
} 