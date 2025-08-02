variable "name" {
  type        = string
  description = "Name prefix for resources"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "lambda_s3_bucket" {
  type        = string
  description = "S3 bucket containing Lambda code"
}

variable "lambda_s3_key" {
  type        = string
  description = "S3 key for Lambda code"
}

variable "delivery_bucket_arn" {
  type        = string
  description = "Destination S3 bucket ARN for Firehose"
}
