output "instance_id" {
  description = "ID da instância EC2"
  value       = aws_instance.this.id
}

output "private_ip" {
  description = "IP privado da instância EC2"
  value       = aws_instance.this.private_ip
}

output "public_ip" {
  description = "IP público da instância EC2 (se houver EIP)"
  value       = try(aws_eip.this[0].public_ip, aws_instance.this.public_ip)
} 