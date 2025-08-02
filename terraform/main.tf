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

module "core_network" {
  source = "./core-network"

  name                 = var.name
  region               = var.region
  vpc_cidr             = var.vpc_cidr
  public_subnet_cidrs  = var.public_subnet_cidrs
  private_subnet_cidrs = var.private_subnet_cidrs
  availability_zones   = var.availability_zones
}

module "data_storage" {
  source = "./data-storage"

  name             = var.name
  region           = var.region
  secondary_region = var.secondary_region
  expo_token       = var.expo_token
}

module "ingest_firehose" {
  source = "./ingest-firehose"

  name                = var.name
  region              = var.region
  lambda_s3_bucket    = var.lambda_s3_bucket
  lambda_s3_key       = var.lambda_s3_key
  delivery_bucket_arn = module.data_storage.bucket_arn
}

module "compute_fargate" {
  source = "./compute-fargate"

  name                = var.name
  region              = var.region
  subnet_ids          = module.core_network.private_subnet_ids
  security_group_ids  = [module.core_network.security_group_id]
  prometheus_endpoint = var.prometheus_endpoint
}

module "api_gateway" {
  source = "./api_gateway"

  region                = var.region
  alerts_table_name     = var.alerts_table_name
  geojson_bucket        = var.geojson_bucket
  cognito_user_pool_arn = var.cognito_user_pool_arn
}

module "edge_frontend" {
  source = "./edge-frontend"

  name               = var.name
  region             = var.region
  domain_name        = var.domain_name
  origin_domain_name = var.origin_domain_name
  hosted_zone_id     = var.hosted_zone_id
}

module "api_gateway" {
  source = "./api_gateway"

  region                = var.region
  cognito_user_pool_arn = var.cognito_user_pool_arn
  geo_fences_table_name = module.data_storage.geo_fences_table_name
  geojson_bucket        = module.data_storage.bucket_name
}
