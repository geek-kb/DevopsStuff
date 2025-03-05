output "arn" {
  description = "The ARN of the IAM role"
  value       = one(aws_iam_role.this[*].arn)
}

output "id" {
  description = "The IAM Role name"
  value       = one(aws_iam_role.this[*].id)
}
