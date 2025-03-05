# Dead-letter Queue (if enabled)
resource "aws_sqs_queue" "dead_letter" {
  count = var.enable_dead_letter_queue ? 1 : 0

  name                      = var.dead_letter_queue_name
  message_retention_seconds = var.message_retention_seconds

  tags = var.tags
}

# Main SQS Queue
resource "aws_sqs_queue" "this" {
  name                        = var.queue_name
  fifo_queue                  = var.fifo_queue
  content_based_deduplication = var.fifo_queue ? var.content_based_deduplication : null

  visibility_timeout_seconds = var.visibility_timeout_seconds
  message_retention_seconds  = var.message_retention_seconds
  max_message_size           = var.max_message_size
  delay_seconds              = var.delay_seconds
  receive_wait_time_seconds  = var.receive_wait_time_seconds

  # Encryption (if enabled)
  kms_master_key_id = var.enable_encryption ? var.kms_key_arn : null

  # Redrive policy (if DLQ is enabled)
  redrive_policy = var.enable_dead_letter_queue ? jsonencode({
    deadLetterTargetArn = aws_sqs_queue.dead_letter[0].arn
    maxReceiveCount     = var.max_receive_count
  }) : null

  tags = var.tags
}

# Queue policy (if provided)
resource "aws_sqs_queue_policy" "this" {
  count     = var.queue_policy != "" ? 1 : 0
  queue_url = aws_sqs_queue.this.id
  policy    = var.queue_policy
}
