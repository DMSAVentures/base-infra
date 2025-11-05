# Multi-App ECS Configuration
# Runs all API containers in a single ECS service with one task definition

# ECS Task Definition with multiple containers
resource "aws_ecs_task_definition" "multi_app_task" {
  family             = "multi-app-api"
  execution_role_arn = aws_iam_role.ecs_task_role.arn

  # Combine all app container definitions
  container_definitions = jsonencode([
    for app_name in keys(local.apps_config) :
    module.app_api[app_name].container_definition
  ])

  tags = {
    Name = "Multi-App API Task Definition"
  }
}

# ECS Service running all API containers
resource "aws_ecs_service" "multi_app_service" {
  name            = "multi-app-api-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  desired_count   = 1
  launch_type     = "EC2"
  task_definition = aws_ecs_task_definition.multi_app_task.arn
  iam_role        = aws_iam_role.ecs_service_role.name

  # Create load balancer configuration for each app
  dynamic "load_balancer" {
    for_each = local.apps_config

    content {
      container_name   = "${load_balancer.key}-api"
      container_port   = load_balancer.value.api_port
      target_group_arn = module.app_api[load_balancer.key].target_group_arn
    }
  }

  depends_on = [
    module.app_api,
    aws_ecs_task_definition.multi_app_task
  ]

  tags = {
    Name = "Multi-App API Service"
  }
}
