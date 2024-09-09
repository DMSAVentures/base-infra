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
