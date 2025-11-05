# App Database Module
# Creates a database on the shared RDS instance for an app

variable "app_name" {
  description = "Application name"
  type        = string
}

variable "database_name" {
  description = "Name of the database to create"
  type        = string
}

variable "db_instance_endpoint" {
  description = "Endpoint of the shared RDS instance"
  type        = string
}

variable "db_master_username" {
  description = "Master username for the RDS instance"
  type        = string
  sensitive   = true
}

variable "db_master_password" {
  description = "Master password for the RDS instance"
  type        = string
  sensitive   = true
}

# Generate unique database credentials for this app
resource "random_string" "db_username" {
  length  = 16
  special = false
  upper   = false
}

resource "random_password" "db_password" {
  length  = 32
  special = true
}

# Store database credentials in SSM Parameter Store
resource "aws_ssm_parameter" "db_endpoint" {
  name  = "/${var.app_name}/db/endpoint"
  type  = "String"
  value = var.db_instance_endpoint

  tags = {
    App = var.app_name
  }
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/${var.app_name}/db/name"
  type  = "String"
  value = var.database_name

  tags = {
    App = var.app_name
  }
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/${var.app_name}/db/username"
  type  = "SecureString"
  value = random_string.db_username.result

  tags = {
    App = var.app_name
  }
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/${var.app_name}/db/password"
  type  = "SecureString"
  value = random_password.db_password.result

  tags = {
    App = var.app_name
  }
}

# Note: The actual database and user creation on the RDS instance
# needs to be done via a null_resource with a provisioner or manually.
# For now, we're storing the credentials that will be used.

# Outputs
output "db_endpoint" {
  description = "Database endpoint"
  value       = var.db_instance_endpoint
}

output "db_name" {
  description = "Database name"
  value       = var.database_name
}

output "db_username" {
  description = "Database username"
  value       = random_string.db_username.result
  sensitive   = true
}

output "db_password" {
  description = "Database password"
  value       = random_password.db_password.result
  sensitive   = true
}

output "ssm_parameter_db_endpoint" {
  description = "SSM parameter name for DB endpoint"
  value       = aws_ssm_parameter.db_endpoint.name
}

output "ssm_parameter_db_name" {
  description = "SSM parameter name for DB name"
  value       = aws_ssm_parameter.db_name.name
}

output "ssm_parameter_db_username" {
  description = "SSM parameter name for DB username"
  value       = aws_ssm_parameter.db_username.name
}

output "ssm_parameter_db_password" {
  description = "SSM parameter name for DB password"
  value       = aws_ssm_parameter.db_password.name
}
