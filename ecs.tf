resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs-cluster"
}

resource "aws_iam_role" "ecs_service_role" {
  name = "ecsServiceRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs.amazonaws.com"
        },
        Action  = "sts:AssumeRole",
      },
    ],
  })
}

resource "aws_iam_role" "ec2_role" {
  name               = "ec2Role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ec2.amazonaws.com"
        },
        Action = "sts:AssumeRole",
      },
    ],
  })
}

resource "aws_iam_role_policy_attachment" "ecs_service_role_policy" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceRole"
  role       = aws_iam_role.ecs_service_role.name
}

resource "aws_iam_instance_profile" "ecs_instance_profile" {
  name = "ecs_instance_profile"
  role = aws_iam_role.ec2_role.name
}

resource "aws_iam_role_policy_attachment" "ecs_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonEC2ContainerServiceforEC2Role"
  role       = aws_iam_role.ec2_role.name
}

resource "aws_iam_role" "ecs_task_role" {
  name               = "ecsTaskRole"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = {
        Service = ["ecs-tasks.amazonaws.com"]
      },
      Action = ["sts:AssumeRole"],
    }],
  })
}

# Attach the ecs_task_policy to the ecs_task_role
resource "aws_iam_role_policy_attachment" "ecs_task_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
  role       = aws_iam_role.ecs_task_role.name
}


resource "aws_ecs_task_definition" "task_definition" {
  family                = "base-app"
  execution_role_arn = aws_iam_role.ecs_task_role.arn
  container_definitions = jsonencode([
    {
      name         = "base-app"
      image        = "nginx:latest"
      cpu          = 256
      memory       = 512
      essential    = true
      portMappings = [
        {
          containerPort = 80
          hostPort      = 80
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options   = {
          awslogs-group         = aws_cloudwatch_log_group.ecs_log_group.name
          awslogs-region        = "us-east-1"
          awslogs-stream-prefix = "ecs-base-server"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "ecs_service" {
  name           = "ECSService"
  cluster        = aws_ecs_cluster.ecs_cluster.id
  desired_count  = 1
  load_balancer {
    container_name = "base-app"
    container_port = 80
    target_group_arn = aws_alb_target_group.ecs_target.arn
  }
  launch_type     = "EC2"
  task_definition = aws_ecs_task_definition.task_definition.arn
  iam_role        = aws_iam_role.ecs_service_role.name
}

# CloudWatch Log Group
resource "aws_cloudwatch_log_group" "ecs_log_group" {
  name              = "base-app-logs"
  retention_in_days = 14
}

# AutoScaling Group
resource "aws_autoscaling_group" "ecs_autoscaling" {
  vpc_zone_identifier = [aws_subnet.public_subnet_a.id, aws_subnet.public_subnet_b.id]
  min_size            = 1
  max_size            = 1
  desired_capacity    = 1

  launch_configuration = aws_launch_configuration.app_launch_config.name
  tag {
    key                 = "Name"
    value               = "ECS AutoScaling Group"
    propagate_at_launch = true
  }
}


resource "aws_launch_configuration" "app_launch_config" {
  name = "app-launch-config"
  image_id             = "ami-0af9e559c6749eb48"
  instance_type        = "t2.micro"  # t2.micro is eligible for the AWS Free Tier
  security_groups      = [aws_security_group.web_dmz.id]
  iam_instance_profile = aws_iam_instance_profile.ecs_instance_profile.name
  user_data            = <<-EOF
                #!/bin/bash
                echo ECS_CLUSTER=${aws_ecs_cluster.ecs_cluster.id} >> /etc/ecs/ecs.config
                EOF
}
