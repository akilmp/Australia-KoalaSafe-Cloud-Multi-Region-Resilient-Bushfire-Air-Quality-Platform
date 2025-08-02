variable "region" {
  description = "AWS region"
  type        = string
  default     = "ap-southeast-2"
}

variable "cognito_user_pool_arn" {
  description = "ARN of Cognito User Pool"
  type        = string
}

variable "alerts_table_name" {
  description = "DynamoDB table for alert subscriptions"
  type        = string
}

variable "geojson_bucket" {
  description = "S3 bucket containing latest GeoJSON"
  type        = string
}

variable "geojson_key" {
  description = "Key for latest GeoJSON object"
  type        = string
  default     = "latest.geojson"
}
