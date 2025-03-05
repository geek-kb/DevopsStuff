resource "aws_ecr_repository" "this" {
  name                 = var.repository_name
  image_tag_mutability = var.image_tag_mutability

  image_scanning_configuration {
    scan_on_push = var.scan_on_push
  }

  dynamic "encryption_configuration" {
    for_each = var.enable_kms_encryption ? [1] : []
    content {
      encryption_type = "KMS"
      kms_key         = var.kms_key_arn
    }
  }

  tags = var.tags
}

resource "aws_ecr_lifecycle_policy" "this" {
  repository = aws_ecr_repository.this.name
  policy     = jsonencode(var.lifecycle_policy)
}
