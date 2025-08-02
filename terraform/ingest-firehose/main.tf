provider "aws" {
  region = var.region
}

resource "aws_iam_role" "lambda_exec" {
  name = "${var.name}-lambda-exec"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
    }]
  })
}

resource "aws_lambda_function" "processor" {
  function_name = "${var.name}-processor"
  s3_bucket     = var.lambda_s3_bucket
  s3_key        = var.lambda_s3_key
  role          = aws_iam_role.lambda_exec.arn
  handler       = "index.handler"
  runtime       = "python3.11"
}

resource "aws_iam_role" "firehose" {
  name = "${var.name}-firehose-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "firehose.amazonaws.com" }
    }]
  })
}

resource "aws_kinesis_firehose_delivery_stream" "stream" {
  name        = "${var.name}-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    bucket_arn = var.delivery_bucket_arn
    role_arn   = aws_iam_role.firehose.arn
  }
}
