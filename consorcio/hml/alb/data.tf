data "aws_caller_identity" "current" {}

data "aws_partition" "current" {}

data "aws_instance" "web" {
  for_each    = var.instance_ids
  instance_id = each.value
}

data "aws_subnet" "alb" {
  for_each = toset(var.subnet_ids)
  id       = each.value
}

data "archive_file" "worker" {
  type        = "zip"
  source_file = "${path.module}/worker.py"
  output_path = "${path.module}/worker.zip"
}
