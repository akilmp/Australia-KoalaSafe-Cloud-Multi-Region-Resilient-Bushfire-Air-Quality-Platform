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

# Schedule to run every 30 seconds
resource "aws_cloudwatch_event_rule" "ingest_schedule" {
  name                = "${var.name}-ingest-schedule"
  schedule_expression = "rate(30 seconds)"
}

resource "aws_cloudwatch_event_target" "ingest_target" {
  rule      = aws_cloudwatch_event_rule.ingest_schedule.name
  target_id = "lambda"
  arn       = aws_lambda_function.processor.arn
}

resource "aws_lambda_permission" "allow_events" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.processor.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.ingest_schedule.arn
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
