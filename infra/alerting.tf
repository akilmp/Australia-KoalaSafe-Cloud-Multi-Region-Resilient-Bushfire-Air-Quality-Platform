# DynamoDB table with stream for geo fences
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
}

data "archive_file" "rule_eval" {
  type        = "zip"
  source_file = "${path.module}/../lambda/rule_eval.py"
  output_path = "${path.module}/../lambda/rule_eval.zip"
}

resource "aws_iam_role" "rule_eval" {
  name = "rule-eval-role"
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
  name = "rule-eval-policy"
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
  function_name    = "rule_eval"
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

# KMS encrypted SNS topic for fire alerts
resource "aws_kms_key" "fire_alert" {
  description = "KMS key for fire-alert SNS topic"
}

resource "aws_sns_topic" "fire_alert" {
  name              = "fire-alert"
  kms_master_key_id = aws_kms_key.fire_alert.arn
}

resource "aws_sns_topic_subscription" "sms" {
  for_each  = var.au_sms_numbers
  topic_arn = aws_sns_topic.fire_alert.arn
  protocol  = "sms"
  endpoint  = each.key

  filter_policy = jsonencode({
    region = [each.value]
  })
}

data "archive_file" "push_bridge" {
  type        = "zip"
  source_file = "${path.module}/../lambda/push_bridge.py"
  output_path = "${path.module}/../lambda/push_bridge.zip"
}

resource "aws_iam_role" "push_bridge" {
  name = "push-bridge-role"
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
  function_name    = "push_bridge"
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

# EventBridge rule to dispatch events to SNS and push bridge
resource "aws_cloudwatch_event_rule" "fire_dispatch" {
  name = "fire-dispatch"
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

resource "aws_cloudwatch_event_target" "push_bridge_target" {
  rule      = aws_cloudwatch_event_rule.fire_dispatch.name
  target_id = "push-bridge"
  arn       = aws_lambda_function.push_bridge.arn
}

resource "aws_lambda_permission" "allow_eventbridge_invoke_push_bridge" {
  statement_id  = "AllowExecutionFromEventBridge"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.push_bridge.function_name
  principal     = "events.amazonaws.com"
  source_arn    = aws_cloudwatch_event_rule.fire_dispatch.arn
}
