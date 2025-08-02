provider "aws" {
  region = var.region
}

data "archive_file" "geojson_proxy" {
  type        = "zip"
  source_file = "${path.module}/../../src/api/geojson_proxy.py"
  output_path = "${path.module}/dist/geojson_proxy.zip"
}

data "archive_file" "subscribe" {
  type        = "zip"
  source_file = "${path.module}/../../src/api/subscribe.py"
  output_path = "${path.module}/dist/subscribe.zip"
}

data "archive_file" "unsubscribe" {
  type        = "zip"
  source_file = "${path.module}/../../src/api/unsubscribe.py"
  output_path = "${path.module}/dist/unsubscribe.zip"
}

resource "aws_iam_role" "lambda" {
  name = "ks-api-lambda-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Service = "lambda.amazonaws.com" }
      Action    = "sts:AssumeRole"
    }]
  })
}

resource "aws_iam_role_policy_attachment" "lambda_basic" {
  role       = aws_iam_role.lambda.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
}

resource "aws_iam_role_policy" "lambda_extra" {
  role = aws_iam_role.lambda.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:GetObject"],
        Resource = "arn:aws:s3:::${var.geojson_bucket}/${var.geojson_key}"
      },
      {
        Effect   = "Allow"
        Action   = ["dynamodb:PutItem", "dynamodb:DeleteItem"],
        Resource = "arn:aws:dynamodb:*:*:table/${var.geo_fences_table_name}"
      }
    ]
  })
}

resource "aws_lambda_function" "geojson_proxy" {
  function_name    = "geojsonProxyFn"
  handler          = "geojson_proxy.geojsonProxyFn"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.geojson_proxy.output_path
  source_code_hash = data.archive_file.geojson_proxy.output_base64sha256
  environment {
    variables = {
      GEOJSON_BUCKET = var.geojson_bucket
      GEOJSON_KEY    = var.geojson_key
    }
  }
}

resource "aws_lambda_function" "subscribe" {
  function_name    = "subscribeFn"
  handler          = "subscribe.subscribeFn"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.subscribe.output_path
  source_code_hash = data.archive_file.subscribe.output_base64sha256
  environment {
    variables = {
      ALERTS_TABLE = var.geo_fences_table_name
    }
  }
}

resource "aws_lambda_function" "unsubscribe" {
  function_name    = "unsubscribeFn"
  handler          = "unsubscribe.unsubscribeFn"
  runtime          = "python3.12"
  role             = aws_iam_role.lambda.arn
  filename         = data.archive_file.unsubscribe.output_path
  source_code_hash = data.archive_file.unsubscribe.output_base64sha256
  environment {
    variables = {
      ALERTS_TABLE = var.geo_fences_table_name
    }
  }
}

resource "aws_api_gateway_rest_api" "api" {
  name        = "koalasafe-api"
  description = "KoalaSafe API"
}

resource "aws_api_gateway_resource" "geojson" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "geojson"
}

resource "aws_api_gateway_resource" "latest" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.geojson.id
  path_part   = "latest"
}

resource "aws_api_gateway_resource" "alerts" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_rest_api.api.root_resource_id
  path_part   = "alerts"
}

resource "aws_api_gateway_resource" "subscribe" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.alerts.id
  path_part   = "subscribe"
}

resource "aws_api_gateway_resource" "alert" {
  rest_api_id = aws_api_gateway_rest_api.api.id
  parent_id   = aws_api_gateway_resource.alerts.id
  path_part   = "{id}"
}

resource "aws_api_gateway_authorizer" "cognito" {
  name          = "cognito-authorizer"
  rest_api_id   = aws_api_gateway_rest_api.api.id
  type          = "COGNITO_USER_POOLS"
  provider_arns = [var.cognito_user_pool_arn]
}

resource "aws_api_gateway_method" "get_latest" {
  rest_api_id      = aws_api_gateway_rest_api.api.id
  resource_id      = aws_api_gateway_resource.latest.id
  http_method      = "GET"
  authorization    = "NONE"
  api_key_required = true
}

resource "aws_api_gateway_method" "post_subscribe" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.subscribe.id
  http_method   = "POST"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_method" "delete_alert" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  resource_id   = aws_api_gateway_resource.alert.id
  http_method   = "DELETE"
  authorization = "COGNITO_USER_POOLS"
  authorizer_id = aws_api_gateway_authorizer.cognito.id
}

resource "aws_api_gateway_integration" "get_latest" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.latest.id
  http_method             = aws_api_gateway_method.get_latest.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.geojson_proxy.invoke_arn
}

resource "aws_api_gateway_integration" "post_subscribe" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.subscribe.id
  http_method             = aws_api_gateway_method.post_subscribe.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.subscribe.invoke_arn
}

resource "aws_api_gateway_integration" "delete_alert" {
  rest_api_id             = aws_api_gateway_rest_api.api.id
  resource_id             = aws_api_gateway_resource.alert.id
  http_method             = aws_api_gateway_method.delete_alert.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.unsubscribe.invoke_arn
}

resource "aws_lambda_permission" "apigw_geojson" {
  statement_id  = "AllowAPIGatewayInvokeGeo"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.geojson_proxy.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/GET/geojson/latest"
}

resource "aws_lambda_permission" "apigw_subscribe" {
  statement_id  = "AllowAPIGatewayInvokeSub"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.subscribe.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/POST/alerts/subscribe"
}

resource "aws_lambda_permission" "apigw_unsubscribe" {
  statement_id  = "AllowAPIGatewayInvokeUnsub"
  action        = "lambda:InvokeFunction"
  function_name = aws_lambda_function.unsubscribe.function_name
  principal     = "apigateway.amazonaws.com"
  source_arn    = "${aws_api_gateway_rest_api.api.execution_arn}/*/DELETE/alerts/*"
}

resource "aws_api_gateway_deployment" "api" {
  depends_on = [
    aws_api_gateway_integration.get_latest,
    aws_api_gateway_integration.post_subscribe,
    aws_api_gateway_integration.delete_alert
  ]
  rest_api_id = aws_api_gateway_rest_api.api.id
}

resource "aws_api_gateway_stage" "prod" {
  rest_api_id   = aws_api_gateway_rest_api.api.id
  deployment_id = aws_api_gateway_deployment.api.id
  stage_name    = "prod"
}

resource "aws_api_gateway_api_key" "geojson" {
  name = "geojson-key"
}

resource "aws_api_gateway_usage_plan" "geojson" {
  name = "geojson-plan"
  api_stages {
    api_id = aws_api_gateway_rest_api.api.id
    stage  = aws_api_gateway_stage.prod.stage_name
  }
}

resource "aws_api_gateway_usage_plan_key" "geojson" {
  key_id        = aws_api_gateway_api_key.geojson.id
  key_type      = "API_KEY"
  usage_plan_id = aws_api_gateway_usage_plan.geojson.id
}
