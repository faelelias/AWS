# Estado OPERACIONAL do failover. Backend do Terraform: tf_01_backend.tf.
resource "aws_dynamodb_table" "state" {
  name         = "${var.name}-state"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"
  attribute {
    name = "id"
    type = "S"
  }
  point_in_time_recovery { enabled = true }
}
