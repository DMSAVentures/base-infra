# Webapp Module - S3 + CloudFront for Vite Apps
# Creates static hosting infrastructure for a single web application

variable "app_name" {
  description = "Application name (used for resource naming)"
  type        = string
}

variable "domain" {
  description = "Domain name for the webapp (e.g., protoapp.xyz)"
  type        = string
}

variable "environment" {
  description = "Environment (production, staging, etc.)"
  type        = string
  default     = "production"
}

variable "alb_dns_name" {
  description = "DNS name of the ALB for API origin"
  type        = string
}

variable "acm_certificate_arn" {
  description = "ARN of the ACM certificate for HTTPS"
  type        = string
}

# S3 Bucket for Static Hosting
resource "aws_s3_bucket" "webapp_bucket" {
  bucket = "${var.domain}-webapp"

  tags = {
    Name        = "${var.app_name} Webapp Bucket"
    Environment = var.environment
    App         = var.app_name
  }
}

# Block public access (CloudFront will access via OAC)
resource "aws_s3_bucket_public_access_block" "webapp_bucket_public_access" {
  bucket = aws_s3_bucket.webapp_bucket.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# S3 Bucket Policy for CloudFront Access
resource "aws_s3_bucket_policy" "webapp_bucket_policy" {
  bucket = aws_s3_bucket.webapp_bucket.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudFrontServicePrincipal"
        Effect = "Allow"
        Principal = {
          Service = "cloudfront.amazonaws.com"
        }
        Action   = "s3:GetObject"
        Resource = "${aws_s3_bucket.webapp_bucket.arn}/*"
        Condition = {
          StringEquals = {
            "AWS:SourceArn" = aws_cloudfront_distribution.webapp_distribution.arn
          }
        }
      }
    ]
  })
}

# CloudFront Origin Access Control
resource "aws_cloudfront_origin_access_control" "webapp_oac" {
  name                              = "${var.app_name}-webapp-oac"
  description                       = "OAC for ${var.app_name} Webapp S3 Bucket"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# CloudFront Function for SPA routing
resource "aws_cloudfront_function" "spa_routing" {
  name    = "${var.app_name}-spa-routing"
  runtime = "cloudfront-js-2.0"
  comment = "Rewrite requests to index.html for ${var.app_name} SPA routing"
  publish = true
  code    = <<-EOT
function handler(event) {
    var request = event.request;
    var uri = request.uri;

    // Don't rewrite API requests
    if (uri.startsWith('/api/')) {
        return request;
    }

    // Check if the URI has a file extension (e.g., .js, .css, .png, .svg)
    // If it does, it's a static asset, so don't rewrite
    if (uri.includes('.')) {
        return request;
    }

    // For all other requests (client-side routes), rewrite to index.html
    request.uri = '/index.html';

    return request;
}
EOT
}

# CloudFront Distribution
resource "aws_cloudfront_distribution" "webapp_distribution" {
  enabled             = true
  is_ipv6_enabled     = true
  default_root_object = "index.html"
  price_class         = "PriceClass_100"
  aliases             = [var.domain, "www.${var.domain}"]

  # S3 Origin for static assets
  origin {
    domain_name              = aws_s3_bucket.webapp_bucket.bucket_regional_domain_name
    origin_id                = "S3-${aws_s3_bucket.webapp_bucket.id}"
    origin_access_control_id = aws_cloudfront_origin_access_control.webapp_oac.id
  }

  # ALB Origin for API requests
  origin {
    domain_name = var.alb_dns_name
    origin_id   = "ALB-API"

    custom_origin_config {
      http_port              = 80
      https_port             = 443
      origin_protocol_policy = "http-only"
      origin_ssl_protocols   = ["TLSv1.2"]
    }

    custom_header {
      name  = "X-App-Name"
      value = var.app_name
    }
  }

  # Default cache behavior (static assets)
  default_cache_behavior {
    allowed_methods  = ["GET", "HEAD", "OPTIONS"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "S3-${aws_s3_bucket.webapp_bucket.id}"

    forwarded_values {
      query_string = false
      cookies {
        forward = "none"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 3600
    max_ttl                = 86400
    compress               = true

    function_association {
      event_type   = "viewer-request"
      function_arn = aws_cloudfront_function.spa_routing.arn
    }
  }

  # API cache behavior
  ordered_cache_behavior {
    path_pattern     = "/api/*"
    allowed_methods  = ["DELETE", "GET", "HEAD", "OPTIONS", "PATCH", "POST", "PUT"]
    cached_methods   = ["GET", "HEAD"]
    target_origin_id = "ALB-API"

    forwarded_values {
      query_string = true
      headers      = ["Authorization", "Content-Type", "Accept", "Origin", "Host"]
      cookies {
        forward = "all"
      }
    }

    viewer_protocol_policy = "redirect-to-https"
    min_ttl                = 0
    default_ttl            = 0
    max_ttl                = 0
    compress               = true
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  viewer_certificate {
    acm_certificate_arn      = var.acm_certificate_arn
    ssl_support_method       = "sni-only"
    minimum_protocol_version = "TLSv1.2_2021"
  }

  tags = {
    Name        = "${var.app_name} CloudFront Distribution"
    Environment = var.environment
    App         = var.app_name
  }
}

# Outputs
output "s3_bucket_name" {
  description = "Name of the S3 bucket"
  value       = aws_s3_bucket.webapp_bucket.bucket
}

output "cloudfront_domain_name" {
  description = "CloudFront distribution domain name"
  value       = aws_cloudfront_distribution.webapp_distribution.domain_name
}

output "cloudfront_distribution_id" {
  description = "CloudFront distribution ID"
  value       = aws_cloudfront_distribution.webapp_distribution.id
}

output "cloudfront_distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.webapp_distribution.arn
}
