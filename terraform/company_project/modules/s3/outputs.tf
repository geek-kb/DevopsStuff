output "s3_bucket_arn" {
  description = "ARN of the S3 bucket"
  value       = aws_s3_bucket.this.arn
}

output "s3_bucket_id" {
  description = "ID (name) of the S3 bucket"
  value       = aws_s3_bucket.this.id
}
