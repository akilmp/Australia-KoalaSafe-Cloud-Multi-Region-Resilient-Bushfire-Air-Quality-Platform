provider "aws" {
  region = var.region
}

provider "aws" {
  alias  = "secondary"
  region = var.secondary_region
}

resource "aws_s3_bucket" "data" {
  bucket        = "${var.name}-data-${terraform.workspace}"
  force_destroy = true

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }

  lifecycle_rule {
    id      = "transition-ia"
    enabled = true

    transition {
      days          = 7
      storage_class = "STANDARD_IA"
    }
  }
}

resource "aws_s3_bucket" "data_replica" {
  provider      = aws.secondary
  bucket        = "${var.name}-data-${terraform.workspace}-replica"
  force_destroy = true

  versioning {
    enabled = true
  }

  server_side_encryption_configuration {
    rule {
      apply_server_side_encryption_by_default {
        sse_algorithm = "AES256"
      }
    }
  }
}

data "aws_iam_policy_document" "replication_assume" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "replication" {
  name               = "${var.name}-replication-role-${terraform.workspace}"
  assume_role_policy = data.aws_iam_policy_document.replication_assume.json
}

data "aws_iam_policy_document" "replication" {
  statement {
    actions = [
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionTagging",
      "s3:GetReplicationConfiguration",
      "s3:ListBucket"
    ]
    resources = [
      aws_s3_bucket.data.arn,
      "${aws_s3_bucket.data.arn}/*"
    ]
  }

  statement {
    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:GetObjectVersionTagging"
    ]
    resources = [
      "${aws_s3_bucket.data_replica.arn}/*"
    ]
  }
}

resource "aws_iam_role_policy" "replication" {
  role   = aws_iam_role.replication.id
  policy = data.aws_iam_policy_document.replication.json
}

resource "aws_s3_bucket_replication_configuration" "data" {
  bucket = aws_s3_bucket.data.id
  role   = aws_iam_role.replication.arn

  rule {
    id     = "replicate-to-secondary"
    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.data_replica.arn
      storage_class = "STANDARD"
    }
  }
}

resource "aws_dynamodb_table" "metadata" {
  name         = "${var.name}-metadata-${terraform.workspace}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }

  replica {
    region_name = var.secondary_region
  }
}

# DynamoDB table storing user geo fences with stream replication
resource "aws_dynamodb_table" "geo_fences" {
  name         = "geo_fences"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "user_id"
  range_key    = "fence_id"

  attribute {
    name = "user_id"
    type = "S"
  }

  attribute {
    name = "fence_id"
    type = "S"
  }

  stream_enabled   = true
  stream_view_type = "NEW_AND_OLD_IMAGES"

  replica {
    region_name = var.secondary_region
  }
}

# Package and deploy rule evaluation Lambda triggered by the table stream
data "archive_file" "rule_eval" {
  type        = "zip"
  source_file = "${path.module}/../../lambda/rule_eval.py"
  output_path = "${path.module}/dist/rule_eval.zip"
}

resource "aws_iam_role" "rule_eval" {
  name = "${var.name}-rule-eval-role-${terraform.workspace}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "rule_eval_logs" {
  role       = aws_iam_role.rule_eval.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "rule_eval" {
  name = "${var.name}-rule-eval-policy-${terraform.workspace}"
  role = aws_iam_role.rule_eval.id
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect   = "Allow",
      Action   = ["events:PutEvents"],
      Resource = "*"
    }]
  })
}

resource "aws_lambda_function" "rule_eval" {
  function_name    = "${var.name}-rule-eval-${terraform.workspace}"
  filename         = data.archive_file.rule_eval.output_path
  source_code_hash = data.archive_file.rule_eval.output_base64sha256
  handler          = "rule_eval.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.rule_eval.arn
}

resource "aws_lambda_event_source_mapping" "geo_fences_stream" {
  event_source_arn  = aws_dynamodb_table.geo_fences.stream_arn
  function_name     = aws_lambda_function.rule_eval.arn
  starting_position = "LATEST"
}

# SNS topic and push bridge Lambda for dispatching alerts
resource "aws_kms_key" "fire_alert" {
  description = "KMS key for fire-alert SNS topic"
}

resource "aws_sns_topic" "fire_alert" {
  name              = "fire-alert"
  kms_master_key_id = aws_kms_key.fire_alert.arn
}

data "archive_file" "push_bridge" {
  type        = "zip"
  source_file = "${path.module}/../../lambda/push_bridge.py"
  output_path = "${path.module}/dist/push_bridge.zip"
}

resource "aws_iam_role" "push_bridge" {
  name = "${var.name}-push-bridge-role-${terraform.workspace}"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [{
      Effect    = "Allow",
      Principal = { Service = "lambda.amazonaws.com" },
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "push_bridge_logs" {
  role       = aws_iam_role.push_bridge.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_lambda_function" "push_bridge" {
  function_name    = "${var.name}-push-bridge-${terraform.workspace}"
  filename         = data.archive_file.push_bridge.output_path
  source_code_hash = data.archive_file.push_bridge.output_base64sha256
  handler          = "push_bridge.lambda_handler"
  runtime          = "python3.12"
  role             = aws_iam_role.push_bridge.arn
  environment {
    variables = {
      EXPO_TOKEN = var.expo_token
    }
  }
}

resource "aws_sns_topic_subscription" "push_bridge" {
  topic_arn = aws_sns_topic.fire_alert.arn
  protocol  = "lambda"
  endpoint  = aws_lambda_function.push_bridge.arn
}

resource "aws_lambda_permission" "allow_sns_push_bridge" {
  statement_id  = "AllowExecutionFromSNS"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.push_bridge.function_name
  principal     = "sns.amazonaws.com"
  source_arn    = aws_sns_topic.fire_alert.arn
}

# Route events from rule evaluation to SNS
resource "aws_cloudwatch_event_rule" "fire_dispatch" {
  name = "${var.name}-fire-dispatch-${terraform.workspace}"
  event_pattern = jsonencode({
    source        = ["koalasafe.rule_eval"],
    "detail-type" = ["FenceIntersection"]
  })
}

resource "aws_cloudwatch_event_target" "sns_target" {
  rule      = aws_cloudwatch_event_rule.fire_dispatch.name
  target_id = "sns"
  arn       = aws_sns_topic.fire_alert.arn
}

resource "aws_lambda_permission" "allow_eventbridge_invoke_rule_eval" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.rule_eval.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.fire_dispatch.arn
}
