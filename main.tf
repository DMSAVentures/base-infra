terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }

    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }

    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

    backend "s3" {
      bucket = "protoapp-infra-terraform-state"
      key    = "state/terraform.tfstate"
      region = "us-east-1"
    }

  required_version = ">= 1.2.0"
}
