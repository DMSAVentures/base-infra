# ECS Service
# Defines the ECS service with desired count, load balancers, and task definition.
resource "aws_ecs_service" "ecs_service" {
  name            = "API Service"  # Service name
  cluster         = aws_ecs_cluster.ecs_cluster.id  # Link to ECS cluster
  desired_count   = 1  # Number of tasks to run
  launch_type     = "EC2"  # EC2 launch type
  task_definition = aws_ecs_task_definition.task_definition.arn  # Reference the task definition
  iam_role        = aws_iam_role.ecs_service_role.name  # ECS service role for permissions

  load_balancer {  # Load balancer configuration
    container_name   = var.container_name_api  # Reference the container name
    container_port   = 80  # Port on the container
    target_group_arn = aws_alb_target_group.ecs_target.arn  # Target group for the load balancer
  }
}

# ECS Task Definition
# Defines the ECS task, including its execution role, container details, and logging configuration.
resource "aws_ecs_task_definition" "task_definition" {
  family                = "base-app"  # Task family
  execution_role_arn    = aws_iam_role.ecs_task_role.arn  # Role for ECS task execution
  container_definitions = jsonencode([
    {
      name         = var.container_name_api  # Container name
      image        = "nginx:latest"  # Docker image to run in ECS
      cpu          = 256  # CPU units
      memory       = 512  # Memory in MB
      essential    = true  # Is this container essential to the task?
      portMappings = [
        {
          containerPort = 80  # Inside the container
          hostPort      = 80  # On the host EC2 instance
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"  # CloudWatch logging
        options   = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_log_group.name  # Log group name
          awslogs-region        = var.aws_region  # AWS region for logging
          awslogs-stream-prefix = var.container_name_api  # Log stream prefix
        }
      }
    }
  ])
}

# CloudWatch Log Group
# Defines a CloudWatch log group for ECS task logging.
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "${var.container_name_api}-logs"  # Log group name
  retention_in_days = 14  # Retention period for logs
}
