output "alb_dns_name" {
  value = aws_lb.k8s_alb.dns_name
  description = "DNS name of the Application Load Balancer (for API only)"
}

output "cloudfront_distribution_id" {
  value = aws_cloudfront_distribution.webapp_distribution.id
  description = "CloudFront distribution ID for webapp"
}

output "cloudfront_domain_name" {
  value = aws_cloudfront_distribution.webapp_distribution.domain_name
  description = "CloudFront distribution domain name"
}

output "webapp_s3_bucket" {
  value = aws_s3_bucket.webapp_bucket.id
  description = "S3 bucket name for webapp static files"
}
