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

resource "aws_iam_policy" "lambda_firehose_access" {
  name = "${var.name}-lambda-firehose-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "firehose:PutRecordBatch"
      Resource = aws_kinesis_firehose_delivery_stream.stream.arn
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_firehose_access" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = aws_iam_policy.lambda_firehose_access.arn
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda_exec.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "processor" {
  function_name = "${var.name}-processor"
  s3_bucket     = var.lambda_s3_bucket
  s3_key        = var.lambda_s3_key
  role          = aws_iam_role.lambda_exec.arn
  handler       = "handlers.handler"
  runtime       = "python3.11"

  environment {
    variables = {
      FIREHOSE_STREAM_NAME = aws_kinesis_firehose_delivery_stream.stream.name
    }
  }
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

resource "aws_iam_policy" "firehose_s3_access" {
  name = "${var.name}-firehose-s3-access"
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect = "Allow"
      Action = [
        "s3:AbortMultipartUpload",
        "s3:GetBucketLocation",
        "s3:GetObject",
        "s3:ListBucket",
        "s3:ListBucketMultipartUploads",
        "s3:PutObject"
      ],
      Resource = [
        var.delivery_bucket_arn,
        "${var.delivery_bucket_arn}/*"
      ]
    }]
  })
}

resource "aws_iam_role_policy_attachment" "firehose_s3_access" {
  role       = aws_iam_role.firehose.name
  policy_arn = aws_iam_policy.firehose_s3_access.arn
}

resource "aws_kinesis_firehose_delivery_stream" "stream" {
  name        = "${var.name}-stream"
  destination = "extended_s3"

  extended_s3_configuration {
    bucket_arn = var.delivery_bucket_arn
    role_arn   = aws_iam_role.firehose.arn
  }
}
