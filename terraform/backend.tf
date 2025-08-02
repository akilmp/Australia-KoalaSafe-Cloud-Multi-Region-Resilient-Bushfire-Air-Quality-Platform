terraform {
  backend "s3" {
    bucket         = "koalasafe-tfstate"
    key            = "terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "koalasafe-tfstate-lock"
    encrypt        = true
  }
}
