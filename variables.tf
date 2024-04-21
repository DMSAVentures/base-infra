variable "cloudflare_email" {
  description = "email"
  type        = string
  default     = "ryan.cyrus@Live.com"
}
variable "cloudflare_api_key" {
  description = "api key"
  type        = string
  default     = "d41ab9728ae6757d3671289abecc01398ae6e"
}
variable "cloudflare_zone_id" {
  description = "zone id"
  type        = string
  default     = "e1fcf5e6c9b60043f75049228a8e3088"
}
variable "domain_name" {
  description = "domain"
  type        = string
  default     = "protoapp.xyz"
}

variable "aws_region" {
  description = "aws region"
    type        = string
    default     = "us-east-1"
}

variable "container_name_api" {
    description = "container name"
    type        = string
    default     = "api"
}

variable "service_name_api" {
  description = "service name"
  type        = string
  default     = "api_service"
}
