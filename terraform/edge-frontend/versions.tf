terraform {
  required_version = ">= 1.0.0"

  backend "s3" {
    bucket               = "koalasafe-terraform-state"
    key                  = "terraform.tfstate"
    region               = "ap-southeast-2"
    dynamodb_table       = "koalasafe-terraform-locks"
    encrypt              = true
    workspace_key_prefix = "edge-frontend"
  }

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
