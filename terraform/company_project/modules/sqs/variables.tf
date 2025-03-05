variable "queue_name" {
  description = "Name of the SQS queue"
  type        = string
}

variable "fifo_queue" {
  description = "Set to true to create a FIFO queue"
  type        = bool
  default     = false
}

variable "content_based_deduplication" {
  description = "Enables content-based deduplication for FIFO queues"
  type        = bool
  default     = false
}

variable "visibility_timeout_seconds" {
  description = "The visibility timeout for the queue (in seconds)"
  type        = number
  default     = 30
}

variable "message_retention_seconds" {
  description = "The message retention period for the queue (in seconds)"
  type        = number
  default     = 345600 # 4 days
}

variable "max_message_size" {
  description = "The maximum message size for the queue (in bytes)"
  type        = number
  default     = 262144
}

variable "delay_seconds" {
  description = "The delay for messages arriving in the queue (in seconds)"
  type        = number
  default     = 0
}

variable "receive_wait_time_seconds" {
  description = "The amount of time that a ReceiveMessage call waits for a message to arrive (in seconds)"
  type        = number
  default     = 0
}

variable "enable_encryption" {
  description = "Enable encryption for the queue using KMS"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (required if enable_encryption = true)"
  type        = string
  default     = ""
}

variable "enable_dead_letter_queue" {
  description = "Enable a dead-letter queue for the SQS queue"
  type        = bool
  default     = false
}

variable "dead_letter_queue_name" {
  description = "The name of the dead-letter queue (required if enable_dead_letter_queue = true)"
  type        = string
  default     = ""
}

variable "max_receive_count" {
  description = "The number of times a message is delivered before moving to the dead-letter queue"
  type        = number
  default     = 5
}

variable "queue_policy" {
  description = "JSON-encoded IAM policy for the SQS queue"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to the SQS queue"
  type        = map(string)
  default     = {}
}
