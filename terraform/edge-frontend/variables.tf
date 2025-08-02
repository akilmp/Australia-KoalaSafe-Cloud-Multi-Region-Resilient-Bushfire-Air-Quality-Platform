variable "name" {
  type        = string
  description = "Name prefix for resources"
}

variable "region" {
  type        = string
  description = "AWS region for ACM and Route53"
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
