# Multi-App ALB Configuration
# Host-based routing ensures API requests go to the correct app

# ALB Listener Rules with HOST-BASED ROUTING
# This prevents API misdirection by matching both host header and path
resource "aws_lb_listener_rule" "app_api_routing" {
  for_each = local.apps_config

  listener_arn = aws_lb_listener.http_listener.arn
  priority     = 100 + index(keys(local.apps_config), each.key)  # Dynamic priority

  action {
    type             = "forward"
    target_group_arn = module.app_api[each.key].target_group_arn
  }

  # CRITICAL: Match BOTH host and path to prevent misdirection
  condition {
    host_header {
      values = [
        each.value.domain,
        "www.${each.value.domain}",
        "*.${each.value.domain}"
      ]
    }
  }

  condition {
    path_pattern {
      values = ["/api/*"]
    }
  }

  tags = {
    App  = each.key
    Name = "${each.key} API Routing Rule"
  }
}

# Output ALB routing rules for verification
output "alb_routing_rules" {
  description = "ALB routing rules for each app (verify no misdirection)"
  value = {
    for app_name, app in local.apps_config : app_name => {
      domain           = app.domain
      api_port         = app.api_port
      target_group_arn = module.app_api[app_name].target_group_arn
      hosts            = [app.domain, "www.${app.domain}", "*.${app.domain}"]
      path             = "/api/*"
    }
  }
}
