terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_sns_topic" "oncall" {
  name = "koalasafe-oncall"
}

resource "aws_sns_topic_subscription" "oncall" {
  topic_arn = aws_sns_topic.oncall.arn
  protocol  = var.oncall_protocol
  endpoint  = var.oncall_endpoint
}

resource "aws_cloudwatch_metric_alarm" "alb_5xx" {
  alarm_name          = "koalasafe-alb-5xx"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HTTPCode_Target_5XX_Count"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Sum"
  threshold           = 1
  dimensions = {
    LoadBalancer = var.alb_name
  }
  alarm_actions = [aws_sns_topic.oncall.arn]
}

resource "aws_cloudwatch_metric_alarm" "fargate_cpu" {
  alarm_name          = "koalasafe-fargate-high-cpu"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 1
  metric_name         = "CPUUtilization"
  namespace           = "AWS/ECS"
  period              = 300
  statistic           = "Average"
  threshold           = 80
  dimensions = {
    ClusterName = var.cluster_name
    ServiceName = var.service_name
  }
  alarm_actions = [aws_sns_topic.oncall.arn]
}

resource "aws_cloudwatch_metric_alarm" "route53_health" {
  alarm_name          = "koalasafe-route53-health"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "HealthCheckStatus"
  namespace           = "AWS/Route53"
  period              = 60
  statistic           = "Minimum"
  threshold           = 1
  dimensions = {
    HealthCheckId = var.health_check_id
  }
  alarm_actions = [aws_sns_topic.oncall.arn]
}

variable "region" {}
variable "oncall_protocol" { default = "email" }
variable "oncall_endpoint" {}
variable "alb_name" {}
variable "cluster_name" {}
variable "service_name" {}
variable "health_check_id" {}
