variable "create_iam_role" {
  description = "Whether to create the IAM role. Set to false to prevent role creation"
  type        = bool
  default     = true
}

variable "role_name" {
  description = "Name of the IAM role to create. Must be unique within the AWS account"
  type        = string
  default     = null
}

variable "assume_role_policy" {
  description = "JSON formatted policy document that controls which entities can assume this role"
  type        = string
  default     = null
}

variable "max_session_duration" {
  description = "Maximum session duration in seconds for the role. Valid values between 3600 and 43200"
  type        = number
  default     = null
}

variable "tags" {
  description = "Map of tags to assign to the IAM role. Key-value pairs for resource organization"
  type        = map(string)
}

variable "managed_iam_policies_to_attach" {
  description = "List of managed IAM policy ARNs to attach to the role"
  type        = list(any)
  default     = []
}

variable "inline_policies_to_attach" {
  description = "Map of inline IAM policies to attach to the role. Each element is a policy document"
  type        = any
  default     = {}
}

variable "kms_policies_to_attach" {
  description = "Map of KMS policies to attach to the IAM role. Controls access to KMS keys"
  type        = map(any)
  default     = {}
}
