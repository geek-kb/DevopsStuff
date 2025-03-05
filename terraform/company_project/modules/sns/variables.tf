variable "topic_name" {
  description = "The name of the SNS topic."
  type        = string
}

variable "display_name" {
  description = "Display name for the SNS topic."
  type        = string
  default     = null
}

variable "kms_master_key_id" {
  description = "KMS key ARN for encrypting SNS messages."
  type        = string
  default     = null
}

variable "allowed_publish_arns" {
  description = "List of AWS ARNs allowed to publish to the SNS topic."
  type        = list(string)
  default     = []
}

variable "subscriptions" {
  description = "List of subscriptions for the SNS topic."
  type = list(object({
    protocol = string
    endpoint = string
    dlq_arn  = optional(string)
  }))
  default = []
}

variable "tags" {
  description = "A map of tags to assign to the SNS topic."
  type        = map(string)
  default     = {}
}

