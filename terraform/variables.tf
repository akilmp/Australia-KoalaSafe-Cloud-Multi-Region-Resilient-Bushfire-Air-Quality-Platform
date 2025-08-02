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

variable "delivery_bucket_arn" {
  type        = string
  description = "Destination S3 bucket ARN for Firehose"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups for compute resources"
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
