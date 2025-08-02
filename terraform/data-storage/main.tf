provider "aws" {
  region = var.region
}

resource "aws_s3_bucket" "data" {
  bucket        = "${var.name}-data-${terraform.workspace}"
  force_destroy = true
}

resource "aws_dynamodb_table" "metadata" {
  name         = "${var.name}-metadata-${terraform.workspace}"
  billing_mode = "PAY_PER_REQUEST"
  hash_key     = "id"

  attribute {
    name = "id"
    type = "S"
  }
}
