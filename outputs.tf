output "alb_dns_name" {
  value = aws_lb.k8s_alb.dns_name
}
