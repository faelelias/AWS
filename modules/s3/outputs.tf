output "bucket_id" {
  description = "ID do bucket S3"
  value       = aws_s3_bucket.this.id
}

output "bucket_arn" {
  description = "ARN do bucket S3"
  value       = aws_s3_bucket.this.arn
}

output "bucket_domain_name" {
  description = "Nome de domínio do bucket S3"
  value       = aws_s3_bucket.this.bucket_domain_name
} 