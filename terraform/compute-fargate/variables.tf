variable "name" {
  type        = string
  description = "Name prefix for resources"
}

variable "region" {
  type        = string
  description = "AWS region"
}

variable "subnet_ids" {
  type        = list(string)
  description = "Subnet IDs for the load balancer"
}

variable "security_group_ids" {
  type        = list(string)
  description = "Security groups for the load balancer"
}

variable "prometheus_endpoint" {
  type        = string
  description = "Remote write endpoint for Prometheus metrics"
}

variable "firehose_bucket" {
  type        = string
  description = "S3 bucket used by Firehose"
}

variable "output_bucket" {
  type        = string
  description = "S3 bucket for processed output"

}
