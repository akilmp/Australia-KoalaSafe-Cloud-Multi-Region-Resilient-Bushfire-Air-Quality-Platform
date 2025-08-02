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

variable "container_image" {
  type        = string
  description = "Container image for the geojson processor"
}
