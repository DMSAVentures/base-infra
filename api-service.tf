# ECS Service
# Defines the ECS service with desired count, load balancers, and task definition.
resource "aws_ecs_service" "ecs_service" {
  name            = var.service_name_api  # Service name
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

data "aws_ecr_repository" "api_service" {
  name = "base-server"
}
data "aws_ssm_parameter" "db_endpoint" {
  name = aws_ssm_parameter.db_endpoint.name
}
data "aws_ssm_parameter" "db_username" {
  name = aws_ssm_parameter.db_username.name
}
data "aws_ssm_parameter" "db_password" {
  name = aws_ssm_parameter.db_password.name
}
data "aws_ssm_parameter" "db_name" {
  name = aws_ssm_parameter.db_name.name
}

data "aws_ssm_parameter" "jwt_secret" {
  name = aws_ssm_parameter.jwt_secret.name
}

data "aws_ssm_parameter" "google_client_id" {
  name = aws_ssm_parameter.google_client_id.name
}

data "aws_ssm_parameter" "google_client_secret" {
  name = aws_ssm_parameter.google_client_secret.name
}

data "aws_ssm_parameter" "google_redirect_uri" {
  name = aws_ssm_parameter.google_redirect_uri.name
}

# ECS Task Definition
# Defines the ECS task, including its execution role, container details, and logging configuration.
resource "aws_ecs_task_definition" "task_definition" {
  family                = "base-server"  # Task family
  execution_role_arn    = aws_iam_role.ecs_task_role.arn  # Role for ECS task execution
  container_definitions = jsonencode([
    {
      name         = var.container_name_api  # Container name
      image        = "${data.aws_ecr_repository.api_service.repository_url}:latest"  # Docker image to run in ECS
      cpu          = 256  # CPU units
      memory       = 512  # Memory in MB
      essential    = true  # Is this container essential to the task?
      portMappings = [
        {
          containerPort = 80  # Inside the container
          hostPort      = 0  # On the host EC2 instance
        }
      ]
      # Health check configuration
      healthCheck = {
        command = [
          "CMD-SHELL",
          "curl -f http://localhost:80/health || exit 1"  # Command to check if the container is healthy
        ]
        interval        = 30  # Time (in seconds) between health checks
        timeout         = 5   # Time (in seconds) to wait for a response before considering it a failure
        retries         = 3   # Number of retries before marking the container as unhealthy
        startPeriod     = 2   # Optional grace period (in seconds) to wait before health checks start
      }
      environment = [  # Environment variables
        {
          name  = "GO_ENV"
          value = var.environment
        },
        {
          name  = "GIN_MODE"
          value = "release"
        },
        {
          name = "DB_HOST"
          value = data.aws_ssm_parameter.db_endpoint.value
        },
        {
          name = "DB_USERNAME"
          value = data.aws_ssm_parameter.db_username.value
        },
        {
          name = "DB_PASSWORD"
          value = data.aws_ssm_parameter.db_password.value
        },
        {
          name = "DB_NAME"
          value = data.aws_ssm_parameter.db_name.value
        },
        {
          name = "JWT_SECRET"
            value = data.aws_ssm_parameter.jwt_secret.value
        },
        {
          name = "GOOGLE_CLIENT_ID"
          value = data.aws_ssm_parameter.google_client_id.value
        },
        {
          name = "GOOGLE_CLIENT_SECRET"
          value = data.aws_ssm_parameter.google_client_secret.value
        },
        {
          name = "GOOGLE_REDIRECT_URI"
          value = data.aws_ssm_parameter.google_redirect_uri.value
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
