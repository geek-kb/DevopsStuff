output "key_id" {
  description = "The ID of the KMS key"
  value       = aws_kms_key.kms_key.id
}

output "key_arn" {
  description = "The ARN of the KMS key"
  value       = aws_kms_key.kms_key.arn
}

output "key_alias" {
  description = "The alias of the KMS key"
  value       = aws_kms_alias.kms_key_alias.name
}
