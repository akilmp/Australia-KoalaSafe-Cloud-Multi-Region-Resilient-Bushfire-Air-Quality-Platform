terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

resource "aws_route53_health_check" "sydney" {
  fqdn              = var.sydney_lb_dns
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_health_check" "melbourne" {
  fqdn              = var.melbourne_lb_dns
  port              = 443
  type              = "HTTPS"
  resource_path     = var.health_check_path
  failure_threshold = 3
  request_interval  = 30
}

resource "aws_route53_record" "sydney" {
  zone_id         = var.hosted_zone_id
  name            = var.domain_name
  type            = "A"
  set_identifier  = "sydney"
  health_check_id = aws_route53_health_check.sydney.id

  weighted_routing_policy {
    weight = 80
  }

  alias {
    name                   = var.sydney_lb_dns
    zone_id                = var.sydney_lb_zone_id
    evaluate_target_health = true
  }
}

resource "aws_route53_record" "melbourne" {
  zone_id         = var.hosted_zone_id
  name            = var.domain_name
  type            = "A"
  set_identifier  = "melbourne"
  health_check_id = aws_route53_health_check.melbourne.id

  weighted_routing_policy {
    weight = 20
  }

  alias {
    name                   = var.melbourne_lb_dns
    zone_id                = var.melbourne_lb_zone_id
    evaluate_target_health = true
  }
}

variable "region" {}
variable "hosted_zone_id" {}
variable "domain_name" {}
variable "sydney_lb_dns" {}
variable "sydney_lb_zone_id" {}
variable "melbourne_lb_dns" {}
variable "melbourne_lb_zone_id" {}
variable "health_check_path" { default = "/" }
