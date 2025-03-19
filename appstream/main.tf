terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}

# Criar o Image Builder
resource "aws_appstream_image_builder" "windows_builder" {
  name                         = "windows-server-2022-builder"
  appstream_agent_version      = "LATEST"
  description                  = "Windows Server 2022 Image Builder"
  display_name                 = "Windows Server 2022 Builder"
  enable_default_internet_access = true
  image_name                   = "Windows-Server-2022"
  instance_type                = "stream.standard.large"
  vpc_config {
    security_group_ids = [aws_security_group.appstream.id]
    subnet_ids         = var.subnet_ids
  }
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Criar o Fleet
resource "aws_appstream_fleet" "windows_fleet" {
  name                         = "windows-server-2022-fleet"
  description                  = "Windows Server 2022 Fleet"
  display_name                 = "Windows Server 2022 Fleet"
  fleet_type                   = "ALWAYS_ON"
  image_name                   = "Windows-Server-2022"
  instance_type                = "stream.standard.large"
  max_user_duration_in_seconds = 3600
  vpc_config {
    security_group_ids = [aws_security_group.appstream.id]
    subnet_ids         = var.subnet_ids
  }
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Criar o Stack
resource "aws_appstream_stack" "windows_stack" {
  name         = "windows-server-2022-stack"
  description  = "Windows Server 2022 Stack"
  display_name = "Windows Server 2022 Stack"
  fleet_name   = aws_appstream_fleet.windows_fleet.name
  tags = {
    Environment = var.environment
    Project     = var.project_name
  }
}

# Security Group para o AppStream
resource "aws_security_group" "appstream" {
  name        = "appstream-sg"
  description = "Security group for AppStream"
  vpc_id      = var.vpc_id

  ingress {
    from_port   = 3389
    to_port     = 3389
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name        = "appstream-sg"
    Environment = var.environment
    Project     = var.project_name
  }
} 