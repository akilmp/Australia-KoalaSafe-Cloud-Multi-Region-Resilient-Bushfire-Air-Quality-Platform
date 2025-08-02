package main

deny[msg] {
  rc := input.resource_changes[_]
  rc.type == "aws_s3_bucket"
  rc.change.after != null
  not rc.change.after.server_side_encryption_configuration
  msg = sprintf("S3 bucket %s must define server_side_encryption_configuration", [rc.address])
}
