# ProtoApp Configuration
# This file defines all settings for the ProtoApp application

# Outputs to be consumed by parent module
output "app_name" {
  value = "protoapp"
}

output "domain" {
  value = "protoapp.xyz"
}

output "api_port" {
  value = 8080
}

output "database_name" {
  value = "protoapp_db"
}

output "api_image_repo" {
  value = "base-server"
}

output "cpu" {
  value = 256
}

output "memory" {
  value = 256
}

# App-specific secrets (reference variables from secrets.tfvars)
variable "google_client_secret" {
  description = "Google OAuth client secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "stripe_secret_key" {
  description = "Stripe secret key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "stripe_webhook_secret" {
  description = "Stripe webhook secret"
  type        = string
  sensitive   = true
  default     = ""
}

variable "resend_api_key" {
  description = "Resend API key for email"
  type        = string
  sensitive   = true
  default     = ""
}

variable "default_email_sender_address" {
  description = "Default email sender address"
  type        = string
  default     = ""
}

variable "gemini_api_key" {
  description = "Google Gemini API key"
  type        = string
  sensitive   = true
  default     = ""
}

variable "openai_api_key" {
  description = "OpenAI API key"
  type        = string
  sensitive   = true
  default     = ""
}
