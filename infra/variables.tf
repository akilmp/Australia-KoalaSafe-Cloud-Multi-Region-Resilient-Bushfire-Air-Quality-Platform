variable "region" {
  type    = string
  default = "ap-southeast-2"
}

variable "au_sms_numbers" {
  description = "Map of Australian phone numbers to their region"
  type        = map(string)
  default     = {}
}

variable "expo_token" {
  description = "Token for Expo Push API"
  type        = string
  default     = ""
}
