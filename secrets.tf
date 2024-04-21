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
