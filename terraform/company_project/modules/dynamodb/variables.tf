variable "table_name" {
  description = "The name of the DynamoDB table"
  type        = string
}

variable "billing_mode" {
  description = "Billing mode for the table (PAY_PER_REQUEST or PROVISIONED)"
  type        = string
  default     = "PAY_PER_REQUEST"
}

variable "hash_key" {
  description = "The attribute name for the hash key"
  type        = string
}

variable "range_key" {
  description = "The attribute name for the range key (if applicable)"
  type        = string
  default     = null
}

variable "attributes" {
  description = "List of attributes for the table"
  type = list(object({
    name = string
    type = string
  }))
  default = []
}

variable "global_secondary_indexes" {
  description = "List of global secondary indexes (GSIs)"
  type = list(object({
    name            = string
    hash_key        = string
    range_key       = optional(string)
    projection_type = string
  }))
  default = []
}

variable "local_secondary_indexes" {
  description = "List of local secondary indexes (LSIs)"
  type = list(object({
    name            = string
    range_key       = string
    projection_type = string
  }))
  default = []
}

variable "server_side_encryption_enabled" {
  description = "Enable server-side encryption"
  type        = bool
  default     = false
}

variable "server_side_encryption_kms_key_arn" {
  description = "KMS key ARN for encryption (required if encryption is enabled)"
  type        = string
  default     = null
}

variable "ttl_enabled" {
  description = "Enable TTL for the table"
  type        = bool
  default     = false
}

variable "ttl_attribute_name" {
  description = "The name of the TTL attribute"
  type        = string
  default     = null
}

variable "point_in_time_recovery_enabled" {
  description = "Enable point-in-time recovery for the table"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags for the DynamoDB table"
  type        = map(string)
  default     = {}
}
