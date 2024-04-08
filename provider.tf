provider "aws" {
  region = "us-east-1"
}
# Retrieve the Cloudflare API key from SSM
data "aws_ssm_parameter" "cloudflare_api_key" {
  name = "/cloudflare/api_key"
}
provider "cloudflare" {
  email   = var.cloudflare_email
  api_key = data.aws_ssm_parameter.cloudflare_api_key.value
}
