output "api_url" {
  description = "Invoke URL of API Gateway stage"
  value       = aws_api_gateway_stage.prod.invoke_url
}

output "usage_plan_id" {
  description = "Usage plan ID for API key association"
  value       = aws_api_gateway_usage_plan.geojson.id
}

output "api_key_value" {
  description = "Generated API key value for geojson access"
  value       = aws_api_gateway_api_key.geojson.value
  sensitive   = true
}
