# Multi-App Orchestration
# Provisions infrastructure for multiple apps

# Define all apps and their configurations
# To add a new app: add a new entry below with unique port and domain
locals {
  apps_config = {
    protoapp = {
      domain         = "protoapp.xyz"
      api_port       = 8080
      api_image_repo = "base-server"
      database_name  = "protoapp_db"
      cpu            = 256
      memory         = 256

      # App-specific environment secrets
      env_secrets = {
        GOOGLE_CLIENT_SECRET         = var.google_client_secret
        STRIPE_SECRET_KEY            = var.stripe_secret_key
        STRIPE_WEBHOOK_SECRET        = var.stripe_webhook_secret
        RESEND_API_KEY               = var.resend_api_key
        DEFAULT_EMAIL_SENDER_ADDRESS = var.default_email_sender_address
        GEMINI_API_KEY               = var.gemini_api_key
        OPENAI_API_KEY               = var.openai_api_key
      }
    }

    # Example of adding a second app:
    # app2 = {
    #   domain         = "app2.com"
    #   api_port       = 8081
    #   api_image_repo = "app2-server"
    #   database_name  = "app2_db"
    #   cpu            = 256
    #   memory         = 256
    #   env_secrets    = {}
    # }
  }
}

# Provision database for each app
module "app_database" {
  source   = "./modules/app-database"
  for_each = local.apps_config

  app_name              = each.key
  database_name         = each.value.database_name
  db_instance_endpoint  = aws_db_instance.default.endpoint
  db_master_username    = aws_db_instance.default.username
  db_master_password    = aws_db_instance.default.password
}

# Provision API service for each app
module "app_api" {
  source   = "./modules/api-service"
  for_each = local.apps_config

  app_name          = each.key
  api_port          = each.value.api_port
  api_image_repo    = each.value.api_image_repo
  cpu               = each.value.cpu
  memory            = each.value.memory
  environment       = var.environment
  aws_region        = var.aws_region
  vpc_id            = aws_vpc.base_vpc.id
  domain            = each.value.domain

  # Database SSM parameters
  db_endpoint_ssm   = module.app_database[each.key].ssm_parameter_db_endpoint
  db_name_ssm       = module.app_database[each.key].ssm_parameter_db_name
  db_username_ssm   = module.app_database[each.key].ssm_parameter_db_username
  db_password_ssm   = module.app_database[each.key].ssm_parameter_db_password

  # App-specific secrets
  app_secrets = each.value.env_secrets

  depends_on = [module.app_database]
}

# Provision ACM certificate for each app
resource "aws_acm_certificate" "app_cert" {
  for_each = local.apps_config

  domain_name               = each.value.domain
  validation_method         = "DNS"
  subject_alternative_names = ["*.${each.value.domain}", "www.${each.value.domain}"]

  lifecycle {
    create_before_destroy = true
  }

  tags = {
    App = each.key
  }
}

# Cloudflare DNS validation for ACM
resource "cloudflare_record" "app_acm_validation" {
  for_each = {
    for dvo in flatten([
      for app_name, app in local.apps_config : [
        for dvo in aws_acm_certificate.app_cert[app_name].domain_validation_options : {
          app_name    = app_name
          domain_name = dvo.domain_name
          domain      = app.domain
          name        = dvo.resource_record_name
          type        = dvo.resource_record_type
          value       = dvo.resource_record_value
        }
      ]
    ]) : "${dvo.app_name}-${dvo.domain_name}" => dvo
    if dvo.domain_name != dvo.domain  # Exclude apex domain for CNAME flattening
  }

  zone_id = var.cloudflare_zone_id
  name    = trimsuffix(each.value.name, ".")
  type    = each.value.type
  value   = each.value.value
  ttl     = 1
}

# Provision webapp (S3 + CloudFront) for each app
module "app_webapp" {
  source   = "./modules/webapp"
  for_each = local.apps_config

  app_name            = each.key
  domain              = each.value.domain
  environment         = var.environment
  alb_dns_name        = aws_lb.k8s_alb.dns_name
  acm_certificate_arn = aws_acm_certificate.app_cert[each.key].arn

  depends_on = [aws_acm_certificate.app_cert]
}

# Cloudflare DNS records for each app
resource "cloudflare_record" "app_root" {
  for_each = local.apps_config

  zone_id = var.cloudflare_zone_id
  name    = each.value.domain == "protoapp.xyz" ? "@" : trimsuffix(each.value.domain, ".com")  # Handle different domains
  type    = "CNAME"
  value   = module.app_webapp[each.key].cloudfront_domain_name
  ttl     = 1
  proxied = false
}

resource "cloudflare_record" "app_www" {
  for_each = local.apps_config

  zone_id = var.cloudflare_zone_id
  name    = "www.${each.value.domain}"
  type    = "CNAME"
  value   = module.app_webapp[each.key].cloudfront_domain_name
  ttl     = 1
  proxied = false
}

# Outputs
output "apps_summary" {
  description = "Summary of all deployed apps"
  value = {
    for app_name in keys(local.apps_config) : app_name => {
      domain              = local.apps_config[app_name].domain
      api_port            = module.app_api[app_name].api_port
      target_group_arn    = module.app_api[app_name].target_group_arn
      cloudfront_domain   = module.app_webapp[app_name].cloudfront_domain_name
      s3_bucket           = module.app_webapp[app_name].s3_bucket_name
    }
  }
}
