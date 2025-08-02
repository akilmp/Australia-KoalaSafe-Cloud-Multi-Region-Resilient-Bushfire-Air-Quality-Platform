output "bucket_name" {
  value = aws_s3_bucket.data.bucket
}

output "dynamodb_table_name" {
  value = aws_dynamodb_table.metadata.name
}

output "geo_fences_table_name" {
  value = aws_dynamodb_table.geo_fences.name
}

output "bucket_arn" {
  value = aws_s3_bucket.data.arn
}
