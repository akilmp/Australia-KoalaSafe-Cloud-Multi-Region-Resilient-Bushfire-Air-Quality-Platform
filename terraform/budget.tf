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

resource "aws_sns_topic" "budget" {
  name = "koalasafe-budget"
}

resource "aws_sns_topic_subscription" "slack" {
  topic_arn = aws_sns_topic.budget.arn
  protocol  = "https"
  endpoint  = var.slack_webhook
}

resource "aws_budgets_budget" "monthly" {
  name         = "koalasafe-monthly-budget"
  budget_type  = "COST"
  limit_amount = var.monthly_limit
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  notification {
    comparison_operator       = "GREATER_THAN"
    threshold                 = 80
    threshold_type            = "PERCENTAGE"
    notification_type         = "FORECASTED"
    subscriber_sns_topic_arns = [aws_sns_topic.budget.arn]
  }
}

variable "region" {}
variable "monthly_limit" {}
variable "slack_webhook" {}
