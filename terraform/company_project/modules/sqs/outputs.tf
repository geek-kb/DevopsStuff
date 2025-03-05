output "sqs_queue_arn" {
  description = "ARN of the SQS queue"
  value       = aws_sqs_queue.this.arn
}

output "sqs_queue_id" {
  description = "ID (name) of the SQS queue"
  value       = aws_sqs_queue.this.id
}

output "sqs_queue_url" {
  description = "ID (name) of the SQS queue"
  value       = aws_sqs_queue.this.url
}

output "dead_letter_queue_arn" {
  description = "ARN of the dead-letter queue (if enabled)"
  value       = var.enable_dead_letter_queue ? aws_sqs_queue.dead_letter[0].arn : null
}
