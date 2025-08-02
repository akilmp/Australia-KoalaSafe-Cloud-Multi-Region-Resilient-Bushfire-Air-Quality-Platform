terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

variable "firehose_bucket" {}
variable "output_bucket" {}
variable "cluster_arn" {}
variable "subnet_ids" { type = list(string) }
variable "security_group_ids" { type = list(string) }
variable "prometheus_endpoint" {}
variable "region" {}

# IAM role for task with S3 access
resource "aws_iam_role" "geojson_task" {
  name               = "geojson-task-role"
  assume_role_policy = data.aws_iam_policy_document.ecs_task_assume.json
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

resource "aws_iam_policy" "geojson_s3" {
  name   = "geojson-s3-access"
  policy = data.aws_iam_policy_document.geojson_s3.json
}

data "aws_iam_policy_document" "geojson_s3" {
  statement {
    actions = ["s3:GetObject", "s3:PutObject", "s3:ListBucket"]
    resources = [
      "arn:aws:s3:::${var.firehose_bucket}",
      "arn:aws:s3:::${var.firehose_bucket}/*",
      "arn:aws:s3:::${var.output_bucket}",
      "arn:aws:s3:::${var.output_bucket}/*"
    ]
  }
}

resource "aws_iam_role_policy_attachment" "geojson_attach" {
  role       = aws_iam_role.geojson_task.name
  policy_arn = aws_iam_policy.geojson_s3.arn
}

# ECS task definition with ADOT sidecar
resource "aws_ecs_task_definition" "geojson" {
  family                   = "geojson-processor"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  task_role_arn            = aws_iam_role.geojson_task.arn
  execution_role_arn       = aws_iam_role.geojson_task.arn

  container_definitions = jsonencode([
    {
      name      = "processor"
      image     = "123456789012.dkr.ecr.${var.region}.amazonaws.com/geojson-processor:latest"
      essential = true
      environment = [
        { name = "FIREHOSE_BUCKET", value = var.firehose_bucket },
        { name = "OUTPUT_BUCKET", value = var.output_bucket }
      ]
      logConfiguration = {
        logDriver = "awslogs"
        options = {
          "awslogs-group"         = "/ecs/geojson-processor"
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
          name  = "AOT_CONFIG_CONTENT",
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
          "awslogs-group"         = "/ecs/geojson-processor"
          "awslogs-region"        = var.region
          "awslogs-stream-prefix" = "adot"
        }
      }
    }
  ])
}

# Schedule to run every 5 minutes
resource "aws_cloudwatch_event_rule" "geojson_schedule" {
  name                = "geojson-five-min"
  schedule_expression = "cron(0/5 * * * ? *)"
}

resource "aws_iam_role" "events" {
  name               = "geojson-events-role"
  assume_role_policy = data.aws_iam_policy_document.events_assume.json
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

resource "aws_iam_role_policy" "events_run_task" {
  name   = "geojson-events-run-task"
  role   = aws_iam_role.events.id
  policy = data.aws_iam_policy_document.events_run_task.json
}

data "aws_iam_policy_document" "events_run_task" {
  statement {
    actions   = ["ecs:RunTask", "iam:PassRole"]
    resources = [aws_ecs_task_definition.geojson.arn, aws_iam_role.geojson_task.arn]
  }
}

resource "aws_cloudwatch_event_target" "geojson_target" {
  rule     = aws_cloudwatch_event_rule.geojson_schedule.name
  arn      = var.cluster_arn
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
