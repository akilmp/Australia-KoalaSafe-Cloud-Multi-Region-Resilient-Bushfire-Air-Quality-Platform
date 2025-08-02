terraform {
  required_version = ">= 1.3.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    archive = {
      source  = "hashicorp/archive"
      version = ">= 2.2.0"
    }
  }
}

provider "aws" {
  region = var.region
}

data "aws_sns_topic" "oncall" {
  name = var.oncall_topic_name
}

resource "aws_s3_bucket" "canary" {
  bucket = "koalasafe-canary-artifacts"
}

resource "aws_iam_role" "canary" {
  name = "koalasafe-canary-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = ["lambda.amazonaws.com", "synthetics.amazonaws.com"]
      }
    }]
  })
}

resource "aws_iam_role_policy_attachment" "canary_basic" {
  role       = aws_iam_role.canary.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy_attachment" "canary_synthetics" {
  role       = aws_iam_role.canary.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchSyntheticsFullAccess"
}

data "archive_file" "geojson" {
  type        = "zip"
  output_path = "${path.module}/geojson_canary.zip"

  source {
    content  = <<-JS
      const https = require("https");
      exports.handler = async () => {
        return new Promise((resolve, reject) => {
          https.get("https://${var.domain_name}/geojson/latest", (res) => {
            res.statusCode === 200 ? resolve() : reject(new Error("Status " + res.statusCode));
          }).on("error", reject);
        });
      };
    JS
    filename = "index.js"
  }
}

resource "aws_synthetics_canary" "geojson" {
  name                 = "koalasafe-geojson-canary"
  artifact_s3_location = "s3://${aws_s3_bucket.canary.bucket}/"
  execution_role_arn   = aws_iam_role.canary.arn
  handler              = "index.handler"
  zip_file             = data.archive_file.geojson.output_path
  runtime_version      = "syn-nodejs-puppeteer-3.9"

  schedule {
    expression = "rate(5 minutes)"
  }
}

resource "aws_cloudwatch_metric_alarm" "geojson_canary_failed" {
  alarm_name          = "koalasafe-geojson-canary-failed"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 1
  metric_name         = "SuccessPercent"
  namespace           = "CloudWatchSynthetics"
  period              = 300
  statistic           = "Average"
  threshold           = 100
  dimensions = {
    CanaryName = aws_synthetics_canary.geojson.name
  }
  alarm_actions = [data.aws_sns_topic.oncall.arn]
}

variable "region" {}

variable "domain_name" {}

variable "oncall_topic_name" {
  default = "koalasafe-oncall"
}
