output "lambda_function_name" {
  value = aws_lambda_function.processor.function_name
}

output "firehose_stream_arn" {
  value = aws_kinesis_firehose_delivery_stream.stream.arn
}
