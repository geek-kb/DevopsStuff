variable "repository_name" {
  type        = string
  description = "Name of the ECR repository."
}

variable "image_tag_mutability" {
  type        = string
  description = "The tag mutability setting for the repository (MUTABLE or IMMUTABLE)."
  default     = "MUTABLE"
}

variable "scan_on_push" {
  type        = bool
  description = "Enable or disable image scanning on push."
  default     = true
}

variable "enable_kms_encryption" {
  type        = bool
  description = "Enable encryption using a customer-managed KMS key (true/false)."
  default     = false
}

variable "kms_key_arn" {
  type        = string
  description = "KMS Key ARN for encryption at rest (only used if `enable_kms_encryption` is true)."
  default     = ""
}

variable "lifecycle_policy" {
  type        = map(any)
  description = "Lifecycle policy for image retention in the repository."
  default = {
    rules = [
      {
        rulePriority = 1
        description  = "Expire untagged images older than 30 days"
        selection = {
          tagStatus   = "untagged"
          countType   = "sinceImagePushed"
          countUnit   = "days"
          countNumber = 30
        }
        action = {
          type = "expire"
        }
      }
    ]
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags to apply to the ECR repository."
  default     = {}
}
