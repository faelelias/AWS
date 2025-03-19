output "endpoint" {
  description = "Endpoint de conexão da instância RDS"
  value       = aws_db_instance.this.endpoint
}

output "arn" {
  description = "ARN da instância RDS"
  value       = aws_db_instance.this.arn
}

output "id" {
  description = "ID da instância RDS"
  value       = aws_db_instance.this.id
}

output "port" {
  description = "Porta da instância RDS"
  value       = aws_db_instance.this.port
} 