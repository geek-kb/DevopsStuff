output "lambda_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.this.arn
}

output "lambda_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.this.invoke_arn
}

output "lambda_function_url" {
  description = "URL of the Lambda function if function URL is enabled"
  value       = aws_lambda_function_url.this[*].function_url
}
