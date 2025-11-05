# API Service Module
# Generates container definition and target group for an API service

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "api_port" {
  description = "Port the API container listens on"
  type        = number
}

variable "api_image_repo" {
  description = "ECR repository name for the API Docker image"
  type        = string
}

variable "cpu" {
  description = "CPU units for the container"
  type        = number
  default     = 256
}

variable "memory" {
  description = "Memory in MB for the container"
  type        = number
  default     = 256
}

variable "environment" {
  description = "Environment name"
  type        = string
}

variable "aws_region" {
  description = "AWS region"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID for target group"
  type        = string
}

variable "db_endpoint_ssm" {
  description = "SSM parameter name for DB endpoint"
  type        = string
}

variable "db_name_ssm" {
  description = "SSM parameter name for DB name"
  type        = string
}

variable "db_username_ssm" {
  description = "SSM parameter name for DB username"
  type        = string
}

variable "db_password_ssm" {
  description = "SSM parameter name for DB password"
  type        = string
}

variable "app_secrets" {
  description = "Map of app-specific secrets"
  type        = map(string)
  default     = {}
  sensitive   = true
}

variable "domain" {
  description = "Domain for the app (used for WEBAPP_URI and other URLs)"
  type        = string
}

# Get ECR repository
data "aws_ecr_repository" "api_repo" {
  name = var.api_image_repo
}

# Fetch database parameters from SSM
data "aws_ssm_parameter" "db_endpoint" {
  name = var.db_endpoint_ssm
}

data "aws_ssm_parameter" "db_name" {
  name = var.db_name_ssm
}

data "aws_ssm_parameter" "db_username" {
  name = var.db_username_ssm
}

data "aws_ssm_parameter" "db_password" {
  name = var.db_password_ssm
}

# Store app secrets in SSM (these come from app-specific variables)
resource "aws_ssm_parameter" "app_secrets" {
  for_each = var.app_secrets

  name  = "/${var.app_name}/secrets/${each.key}"
  type  = "SecureString"
  value = each.value != "" ? each.value : "PLACEHOLDER"

  tags = {
    App = var.app_name
  }

  lifecycle {
    ignore_changes = [value]  # Prevent overwriting if manually updated
  }
}

# Generate JWT secret if needed
resource "random_password" "jwt_secret" {
  length  = 64
  special = true
}

resource "aws_ssm_parameter" "jwt_secret" {
  name  = "/${var.app_name}/secrets/JWT_SECRET"
  type  = "SecureString"
  value = random_password.jwt_secret.result

  tags = {
    App = var.app_name
  }
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "api_logs" {
  name              = "/${var.app_name}/api"
  retention_in_days = 7

  tags = {
    App = var.app_name
  }
}

# ALB Target Group for this app's API
resource "aws_alb_target_group" "api_target" {
  name     = "${var.app_name}-api-tg"
  port     = var.api_port
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    path                = "/health"
    port                = "traffic-port"
    protocol            = "HTTP"
    timeout             = 5
    interval            = 30
    healthy_threshold   = 5
    unhealthy_threshold = 2
  }

  tags = {
    App = var.app_name
  }
}

# Fetch stored secrets from SSM for environment variables
locals {
  # Build environment variables for the container
  environment_vars = [
    { name = "GO_ENV", value = var.environment },
    { name = "GIN_MODE", value = "release" },
    { name = "SERVER_PORT", value = tostring(var.api_port) },
    { name = "DB_HOST", value = data.aws_ssm_parameter.db_endpoint.value },
    { name = "DB_USERNAME", value = data.aws_ssm_parameter.db_username.value },
    { name = "DB_PASSWORD", value = data.aws_ssm_parameter.db_password.value },
    { name = "DB_NAME", value = data.aws_ssm_parameter.db_name.value },
    { name = "JWT_SECRET", value = aws_ssm_parameter.jwt_secret.value },
    { name = "WEBAPP_URI", value = "https://${var.domain}" },
    { name = "GOOGLE_REDIRECT_URI", value = "https://${var.domain}/auth/callback" },
  ]

  # Add app-specific secrets
  secret_env_vars = [
    for key, _ in var.app_secrets : {
      name  = key
      value = try(aws_ssm_parameter.app_secrets[key].value, "")
    }
  ]

  all_env_vars = concat(local.environment_vars, local.secret_env_vars)
}

# Container definition (to be used in task definition)
locals {
  container_definition = {
    name      = "${var.app_name}-api"
    image     = "${data.aws_ecr_repository.api_repo.repository_url}:latest"
    cpu       = var.cpu
    memory    = var.memory
    essential = true

    portMappings = [{
      containerPort = var.api_port
      hostPort      = 0  # Dynamic port mapping
      protocol      = "tcp"
    }]

    healthCheck = {
      command = [
        "CMD-SHELL",
        "curl -f http://localhost:${var.api_port}/health || exit 1"
      ]
      interval    = 30
      timeout     = 5
      retries     = 3
      startPeriod = 60
    }

    environment = local.all_env_vars

    logConfiguration = {
      logDriver = "awslogs"
      options = {
        awslogs-group         = aws_cloudwatch_log_group.api_logs.name
        awslogs-region        = var.aws_region
        awslogs-stream-prefix = var.app_name
      }
    }
  }
}

# Outputs
output "container_definition" {
  description = "Container definition for this app's API"
  value       = local.container_definition
}

output "target_group_arn" {
  description = "ARN of the target group"
  value       = aws_alb_target_group.api_target.arn
}

output "api_port" {
  description = "API port"
  value       = var.api_port
}
