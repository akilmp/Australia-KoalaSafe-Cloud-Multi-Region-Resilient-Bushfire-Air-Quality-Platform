resource "aws_secretsmanager_secret" "nasa_api_key" {
  name = "${var.name}-nasa-api-key"
}

resource "aws_secretsmanager_secret_rotation" "nasa_api_key" {
  secret_id           = aws_secretsmanager_secret.nasa_api_key.id
  rotation_lambda_arn = var.secret_rotation_lambda_arn
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret" "mapbox_token" {
  name = "${var.name}-mapbox-token"
}

resource "aws_secretsmanager_secret_rotation" "mapbox_token" {
  secret_id           = aws_secretsmanager_secret.mapbox_token.id
  rotation_lambda_arn = var.secret_rotation_lambda_arn
  rotation_rules {
    automatically_after_days = 30
  }
}

resource "aws_secretsmanager_secret" "expo_token" {
  name = "${var.name}-expo-token"
}

resource "aws_secretsmanager_secret_rotation" "expo_token" {
  secret_id           = aws_secretsmanager_secret.expo_token.id
  rotation_lambda_arn = var.secret_rotation_lambda_arn
  rotation_rules {
    automatically_after_days = 30
  }
}
