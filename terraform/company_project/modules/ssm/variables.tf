variable "ssm_params" {
  description = "Map of SSM parameters to create with their configurations"
  type        = map(string)
  default     = {}
}

variable "kms_key_id" {
  description = "The KMS key id or arn for encrypting a SecureString"
  type        = string
  default     = "arn:aws:kms:eu-north-1:912466608750:key/00fc7f10-cd91-461e-84d3-0c679e709f53"
}

variable "prefix" {
  description = "Prefix added to ssm parameter name"
  type        = string
  default     = ""
}

variable "unencrypted_suffix" {
  description = "Parameters with this suffix in the name will be saved as plaintext values."
  type        = string
  default     = "_unencrypted"
}
