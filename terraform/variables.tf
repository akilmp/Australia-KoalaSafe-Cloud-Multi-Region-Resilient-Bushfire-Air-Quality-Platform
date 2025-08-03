variable "name" {
  type        = string
  description = "Name prefix for resources"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "secondary_region" {
  type        = string
  description = "Secondary AWS region for replication"
}

variable "vpc_cidr" {
  type        = string
  description = "CIDR block for the VPC"
}

variable "public_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for public subnets"
}

variable "private_subnet_cidrs" {
  type        = list(string)
  description = "CIDR blocks for private subnets"
}

variable "availability_zones" {
  type        = list(string)
  description = "Availability zones for subnets"
}

variable "lambda_s3_bucket" {
  type        = string
  description = "S3 bucket containing Lambda code"
}

variable "lambda_s3_key" {
  type        = string
  description = "S3 key for Lambda code"
}

variable "secret_rotation_lambda_arn" {
  type        = string
  description = "ARN of the Lambda function that rotates secrets"
}


variable "domain_name" {
  type        = string
  description = "Domain name for the frontend"
}

variable "origin_domain_name" {
  type        = string
  description = "Origin domain for CloudFront"
}

variable "hosted_zone_id" {
  type        = string
  description = "Route53 hosted zone ID"
}

variable "cognito_user_pool_arn" {
  type        = string
  description = "ARN of Cognito User Pool"
}


variable "prometheus_endpoint" {
  type        = string
  description = "Prometheus remote write endpoint"
}

variable "container_image" {
  type        = string
  description = "Container image for Fargate task"
}
