variable "name" {
  type        = string
  description = "Name prefix for resources"
}

variable "region" {
  type        = string
  description = "AWS region"
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

variable "nat_gateway_subnet_index" {
  type        = number
  description = "Index of the public subnet in which to place the NAT Gateway"
  default     = 0
}

variable "security_group_ingress_cidr_blocks" {
  type        = list(string)
  description = "CIDR blocks allowed to access the default security group"
  default     = ["0.0.0.0/0"]
}
