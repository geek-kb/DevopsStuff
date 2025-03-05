variable "bucket_name" {
  description = "Name of the S3 bucket"
  type        = string
}

variable "encryption" {
  description = "Enable encryption for the bucket using KMS"
  type        = bool
  default     = false
}

variable "kms_key_arn" {
  description = "KMS key ARN for encryption (required if enable_encryption = true)"
  type        = string
  default     = ""
}

variable "logging" {
  description = "Enable access logging for the bucket"
  type        = bool
  default     = false
}

variable "logging_target_bucket" {
  description = "Target S3 bucket for access logs"
  type        = string
  default     = ""
}

variable "logging_prefix" {
  description = "Prefix for the access logs"
  type        = string
  default     = "logs/"
}

variable "bucket_policy" {
  description = "JSON-encoded bucket policy"
  type        = string
  default     = ""
}

variable "versioning" {
  description = "Enable versioning for the bucket"
  type        = bool
  default     = false
}

variable "lifecycle_rules" {
  description = "A list of lifecycle rules for the bucket"
  type = list(object({
    id     = string
    status = string
    prefix = optional(string, "")
    expiration = optional(object({
      days                         = optional(number)
      expired_object_delete_marker = optional(bool)
    }), {})
    transition = optional(list(object({
      days          = number
      storage_class = string
    })), [])
  }))
  default = []
}

variable "tags" {
  description = "Tags to apply to the bucket"
  type        = map(string)
  default     = {}
}
