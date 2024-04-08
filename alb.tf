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
    target_group_arn = aws_lb_target_group.k8s_tg.arn
  }
}

resource "aws_lb_target_group" "k8s_tg" {
  name     = "k8sTargetGroup"
  port     = 80
  protocol = "HTTP"
  vpc_id   = aws_vpc.base_vpc.id

  health_check {
    enabled             = true
    healthy_threshold   = 5
    unhealthy_threshold = 2
    timeout             = 5
    path                = "/"
    protocol            = "HTTP"
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name = "k8sTargetGroup"
  }
}

resource "aws_lb_target_group_attachment" "protoapp_attach" {
  target_group_arn = aws_lb_target_group.k8s_tg.arn
  target_id        = aws_instance.protoapp.id
  port             = 80
}

