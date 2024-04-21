resource "aws_lb" "k8s_alb" {
  name               = "k8sALB"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [aws_security_group.web_dmz.id]
  subnets            = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]

  enable_deletion_protection = false

  tags = {
    Name = "Default LoadBalancer"
  }
}

resource "aws_lb_listener" "https_listener" {
  load_balancer_arn = aws_lb.k8s_alb.arn
  port              = 443
  protocol          = "HTTPS"
  ssl_policy        = "ELBSecurityPolicy-2016-08"
  certificate_arn   = aws_acm_certificate.ssl_cert.arn # Replace with your SSL certificate ARN

  default_action {
    type             = "forward"
    target_group_arn = aws_alb_target_group.ecs_target.arn
  }
}

resource "aws_alb_target_group" "ecs_target" {
    name        = "ecs-target-group"
    port        = 80
    protocol    = "HTTP"
    vpc_id      = aws_vpc.base_vpc.id

    health_check {
        path                = "/health"
        port                = "traffic-port"
        protocol            = "HTTP"
        timeout             = 5
        interval            = 30
        healthy_threshold   = 5
        unhealthy_threshold = 2
    }
}

## ALB Listener Rule
#resource "aws_lb_listener_rule" "alb_listener_rule" {
#  listener_arn = aws_lb_listener.https_listener.id
#  priority     = 1
#
#  action {
#    type             = "forward"
#    target_group_arn = aws_alb_target_group.ecs_target.arn
#  }
#
#  condition {
#    field   = "path-pattern"
#    values  = ["/"]
#  }
#}
