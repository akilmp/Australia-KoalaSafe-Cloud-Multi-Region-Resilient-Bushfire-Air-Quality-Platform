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

variable "expo_token" {
  type        = string
  description = "Expo push token for push bridge Lambda"
  default     = ""
}
