# Get the current AWS account ID
data "aws_caller_identity" "current" {}

# Create a new KMS Key only if it is not imported
resource "aws_kms_key" "kms_key" {
  description              = "KMS key for secure encryption"
  deletion_window_in_days  = 7
  enable_key_rotation      = var.enable_key_rotation
  key_usage                = var.key_usage
  customer_master_key_spec = var.key_spec
  multi_region             = var.enable_multi_region

  policy = var.kms_policy != "" ? var.kms_policy : jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:root" },
        Action    = "kms:*",
        Resource  = "*"
      },
      {
        Effect    = "Allow",
        Principal = { AWS = "arn:aws:iam::${data.aws_caller_identity.current.account_id}:user/itaig" },
        Action    = "kms:*",
        Resource  = "*"
      }
    ]
  })

  tags = var.tags
}

# Create a KMS Alias
resource "aws_kms_alias" "kms_key_alias" {
  name          = "alias/${var.kms_key_alias}"
  target_key_id = aws_kms_key.kms_key.id
}
