variable "kms_key_alias" {
  description = "Alias for the KMS key"
  type        = string
}

variable "key_usage" {
  description = "The cryptographic operations for which the key can be used (ENCRYPT_DECRYPT, SIGN_VERIFY, etc.)"
  type        = string
  default     = "ENCRYPT_DECRYPT"
}

variable "key_spec" {
  description = "The key spec for the KMS key (SYMMETRIC_DEFAULT, RSA_2048, etc.)"
  type        = string
  default     = "SYMMETRIC_DEFAULT"
}

variable "enable_key_rotation" {
  description = "Enable automatic key rotation"
  type        = bool
  default     = true
}

variable "enable_multi_region" {
  description = "Enable multi-region support for the KMS key"
  type        = bool
  default     = false
}

variable "kms_policy" {
  description = "JSON-encoded IAM policy for the KMS key (if empty, a default policy is used)"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to the KMS key"
  type        = map(string)
  default     = {}
}
