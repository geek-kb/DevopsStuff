resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
  tags   = var.tags
}

# Versioning (if enabled)
resource "aws_s3_bucket_versioning" "this" {
  count = var.versioning ? 1 : 0

  bucket = aws_s3_bucket.this.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Encryption (if enabled)
resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  count = var.encryption ? 1 : 0

  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = var.kms_key_arn != null ? "aws:kms" : "AES256"
      kms_master_key_id = var.kms_key_arn
    }
  }
}

# Logging (if enabled)
resource "aws_s3_bucket_logging" "this" {
  count = var.logging ? 1 : 0

  bucket = aws_s3_bucket.this.id

  target_bucket = var.logging_target_bucket
  target_prefix = var.logging_prefix
}

# Lifecycle Rules (if provided)
resource "aws_s3_bucket_lifecycle_configuration" "this" {
  count  = length(var.lifecycle_rules) > 0 ? 1 : 0
  bucket = aws_s3_bucket.this.id

  dynamic "rule" {
    for_each = var.lifecycle_rules
    content {
      id     = rule.value.id
      status = rule.value.status

      filter {
        prefix = rule.value.prefix
      }

      dynamic "expiration" {
        for_each = length(rule.value.expiration) > 0 ? [rule.value.expiration] : []
        content {
          days                         = lookup(rule.value.expiration, "days", null)
          expired_object_delete_marker = lookup(rule.value.expiration, "expired_object_delete_marker", null)
        }
      }

      dynamic "transition" {
        for_each = lookup(rule.value, "transition", [])
        content {
          days          = transition.value.days
          storage_class = transition.value.storage_class
        }
      }
    }
  }
}

# Bucket policy (if provided)
resource "aws_s3_bucket_policy" "this" {
  count  = var.bucket_policy != "" ? 1 : 0
  bucket = aws_s3_bucket.this.id
  policy = var.bucket_policy
}
