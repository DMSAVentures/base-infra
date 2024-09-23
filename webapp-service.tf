# ECS Service
# Defines the ECS service with desired count, load balancers, and task definition.
resource "aws_ecs_service" "webapp_service" {
  name            = var.service_name_webapp  # Service name
  cluster         = aws_ecs_cluster.ecs_cluster.id  # Link to ECS cluster
  desired_count   = 1  # Number of tasks to run
  launch_type     = "EC2"  # EC2 launch type
  task_definition = aws_ecs_task_definition.webapp_task_definition.arn  # Reference the task definition
  iam_role        = aws_iam_role.ecs_service_role.name  # ECS service role for permissions

  load_balancer {  # Load balancer configuration
    container_name   = var.container_name_webapp  # Reference the container name
    container_port   = 3000  # Port on the container
    target_group_arn = aws_alb_target_group.webapp_ecs_target.arn  # Target group for the load balancer
  }
}

data "aws_ecr_repository" "webapp_service" {
  name = "webapp"
}

# ECS Task Definition
# Defines the ECS task, including its execution role, container details, and logging configuration.
resource "aws_ecs_task_definition" "webapp_task_definition" {
  family                = "web-app"  # Task family
  execution_role_arn    = aws_iam_role.ecs_task_role.arn  # Role for ECS task execution
  container_definitions = jsonencode([
    {
      name         = var.container_name_webapp  # Container name
      image        = "${data.aws_ecr_repository.webapp_service.repository_url}:latest"  # Docker image to run in ECS
      cpu          = 256  # CPU units
      memory       = 256  # Memory in MB
      essential    = true  # Is this container essential to the task?
      portMappings = [
        {
          containerPort = 3000  # Inside the container
          hostPort      = 0  # On the host EC2 instance
        }
      ]
      # Health check configuration
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:3000 || exit 1"  # Command to check if the container is healthy
        ]
        interval        = 30  # Time (in seconds) between health checks
        timeout         = 5   # Time (in seconds) to wait for a response before considering it a failure
        retries         = 3   # Number of retries before marking the container as unhealthy
        startPeriod     = 2   # Optional grace period (in seconds) to wait before health checks start
      }
      environment = [  # Environment variables
        {
          name = "NEXT_PUBLIC_GOOGLE_CLIENT_ID"
          value = "264792512466-81b98c4ctp11qj177mgmj817o23a12bn.apps.googleusercontent.com"
        },
        {
            name = "NEXT_PUBLIC_GOOGLE_REDIRECT_URI"
            value = "https://protoapp.xyz/api/auth/google/callback"
        },
        {
          name = "NEXT_PUBLIC_STRIPE_PUBLISHABLE_KEY"
          value = "pk_live_51PxCuHP3M2g0n0x3rpcflZx5JgmeMo7Le4eQFEj2coL6EwODaZ4L0YsfUGm32hXjzMruRZtmQXqUlvHcz2ZsVCwZ00O8C2Is5h"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"  # CloudWatch logging
        options   = {
          awslogs-group         = aws_cloudwatch_log_group.webapp_ecs_log_group.name  # Log group name
          awslogs-region        = var.aws_region  # AWS region for logging
          awslogs-stream-prefix = var.container_name_webapp  # Log stream prefix
        }
      }
    }
  ])
}

# CloudWatch Log Group
# Defines a CloudWatch log group for ECS task logging.
resource "aws_cloudwatch_log_group" "webapp_ecs_log_group" {
  name              = "${var.container_name_webapp}-logs"  # Log group name
  retention_in_days = 14  # Retention period for logs
}
