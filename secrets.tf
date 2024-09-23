# Generate a random username
resource "random_string" "db_username" {
  length  = 16
  special = false
  upper   = false
  override_special = "_"
  numeric = false
}


# Generate a random password
resource "random_string" "db_password" {
  length           = 16
  special = false
}

# Generate a random JWT secret
resource "random_string" "jwt_secret" {
  length = 32
  special = false
}

resource "aws_ssm_parameter" "db_endpoint" {
  name  = "/db_secrets/protoapp_db_endpoint"
  type  = "String"
  value = aws_db_instance.default.endpoint
}

resource "aws_ssm_parameter" "db_username" {
  name  = "/db_secrets/protoapp_db_username"
  type  = "SecureString"
  value = aws_db_instance.default.username
}

resource "aws_ssm_parameter" "db_password" {
  name  = "/db_secrets/protoapp_db_password"
  type  = "SecureString"
  value = aws_db_instance.default.password
}

resource "aws_ssm_parameter" "db_name" {
  name  = "/db_secrets/protoapp_db_name"
  type  = "String"
  value = "base_db"
}

resource "aws_ssm_parameter" "jwt_secret" {
  name = "/jwt_secrets/protoapp_jwt_secret"
  type = "SecureString"
  value = random_string.jwt_secret.result
}

resource "aws_ssm_parameter" "google_client_id" {
  name = "/google_secrets/protoapp_google_client_id"
  type = "String"
  value = "264792512466-81b98c4ctp11qj177mgmj817o23a12bn.apps.googleusercontent.com"
}

resource "aws_ssm_parameter" "google_client_secret" {
  name = "/google_secrets/protoapp_google_client_secret"
  type = "SecureString"
  value = var.google_client_secret
  lifecycle {
    ignore_changes = [value]  # Ignore changes to the value once it’s set
  }
}

resource "aws_ssm_parameter" "google_redirect_uri" {
  name = "/google_secrets/protoapp_google_redirect_uri"
  type = "String"
  value = "https://protoapp.xyz/api/auth/google/callback"
}

resource "aws_ssm_parameter" "web_app_uri" {
  name = "/api_service/protoapp_web_app_uri"
  type = "String"
  value = "https://protoapp.xyz"
}

resource "aws_ssm_parameter" "stripe_publishable_key" {
  name = "/stripe_secrets/protoapp_stripe_publishable_key"
  type = "String"
  value = "pk_live_51PxCuHP3M2g0n0x3rpcflZx5JgmeMo7Le4eQFEj2coL6EwODaZ4L0YsfUGm32hXjzMruRZtmQXqUlvHcz2ZsVCwZ00O8C2Is5h"
}

resource "aws_ssm_parameter" "stripe_secret_key" {
  name = "/stripe_secrets/protoapp_stripe_secret_key"
  type = "SecureString"
  value = var.stripe_secret_key
  lifecycle {
    ignore_changes = [value]  # Ignore changes to the value once it’s set
  }
}

resource "aws_ssm_parameter" "stripe_webhook_secret" {
  name = "/stripe_secrets/protoapp_stripe_webhook_secret"
  type = "SecureString"
  value = var.stripe_webhook_secret
  lifecycle {
    ignore_changes = [value]  # Ignore changes to the value once it’s set
    }
}
