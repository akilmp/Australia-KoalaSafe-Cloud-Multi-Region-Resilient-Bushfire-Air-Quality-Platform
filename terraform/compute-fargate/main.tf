provider "aws" {
  region = var.region
}

resource "aws_ecs_cluster" "this" {
  name = "${var.name}-cluster"
}

resource "aws_lb" "app" {
  name               = "${var.name}-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = var.subnet_ids
  security_groups    = var.security_group_ids
}

data "aws_subnet" "selected" {
  id = var.subnet_ids[0]
}

resource "aws_lb_target_group" "geojson" {
  name        = "${var.name}-tg"
  port        = 80
  protocol    = "HTTP"
  target_type = "ip"
  vpc_id      = data.aws_subnet.selected.vpc_id
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.app.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.geojson.arn
  }
}

data "aws_iam_policy_document" "ecs_task_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ecs-tasks.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "geojson_task" {
  name               = "${var.name}-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
}

resource "aws_iam_role_policy_attachment" "task_exec" {
  role       = aws_iam_role.geojson_task.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy" "geojson_s3" {
  name = "${var.name}-s3-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
      Effect = "Allow"
      Resource = [
        "arn:aws:s3:::${var.firehose_bucket}",
        "arn:aws:s3:::${var.firehose_bucket}/*",
        "arn:aws:s3:::${var.output_bucket}",
        "arn:aws:s3:::${var.output_bucket}/*",
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "geojson_s3_attach" {
  role       = aws_iam_role.geojson_task.name
  policy_arn = aws_iam_policy.geojson_s3.arn
}

resource "aws_ecs_task_definition" "geojson" {
  family                   = "${var.name}-geojson"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.geojson_task.arn
  task_role_arn            = aws_iam_role.geojson_task.arn

  container_definitions = jsonencode([
    {
      name      = "processor"
      image     = var.container_image
      essential = true
      environment = [
        { name = "FIREHOSE_BUCKET", value = var.firehose_bucket },
        { name = "OUTPUT_BUCKET", value = var.output_bucket }
      ]
      portMappings = [
        {
          containerPort = 80
          protocol      = "tcp"
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.name}-processor"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "ecs"
        }
      }
    },
    {
      name      = "adot-collector"
      image     = "public.ecr.aws/aws-observability/aws-otel-collector:latest"
      essential = false
      command   = ["--config=/etc/ecs/ecs-default-config.yaml"]
      environment = [
        {
          name  = "AOT_CONFIG_CONTENT"
          value = <<EOT
receivers:
  awsecscontainermetrics:
  otlp:
    protocols:
      grpc:
      http:
exporters:
  awsprometheusremotewrite:
    endpoint: "${var.prometheus_endpoint}"
service:
  pipelines:
    metrics:
      receivers: [awsecscontainermetrics]
      exporters: [awsprometheusremotewrite]
    traces:
      receivers: [otlp]
      exporters: [awsprometheusremotewrite]
EOT
        }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/${var.name}-processor"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "adot"
        }
      }
    }
  ])
}

resource "aws_ecs_service" "geojson" {
  name            = "${var.name}-service"
  cluster         = aws_ecs_cluster.this.id
  task_definition = aws_ecs_task_definition.geojson.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = var.subnet_ids
    security_groups  = var.security_group_ids
    assign_public_ip = false
  }

  load_balancer {
    target_group_arn = aws_lb_target_group.geojson.arn
    container_name   = "processor"
    container_port   = 80
  }
}

resource "aws_cloudwatch_event_rule" "geojson_schedule" {
  name                = "${var.name}-schedule"
  schedule_expression = "cron(0/5 * * * ? *)"
}

data "aws_iam_policy_document" "events_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["events.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "events" {
  name               = "${var.name}-events-role"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
}

data "aws_iam_policy_document" "events_run_task" {
  statement {
    actions   = ["ecs:RunTask", "iam:PassRole"]
    resources = [aws_ecs_task_definition.geojson.arn, aws_iam_role.geojson_task.arn]
  }
}

resource "aws_iam_role_policy" "events_run_task" {
  name   = "${var.name}-events-policy"
  role   = aws_iam_role.events.id
  policy = data.aws_iam_policy_document.events_run_task.json
}

resource "aws_cloudwatch_event_target" "geojson_target" {
  rule     = aws_cloudwatch_event_rule.geojson_schedule.name
  arn      = aws_ecs_cluster.this.arn
  role_arn = aws_iam_role.events.arn

  ecs_target {
    launch_type         = "FARGATE"
    task_definition_arn = aws_ecs_task_definition.geojson.arn
    network_configuration {
      subnets          = var.subnet_ids
      security_groups  = var.security_group_ids
      assign_public_ip = false
    }
  }
}
