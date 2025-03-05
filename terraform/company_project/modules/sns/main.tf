resource "aws_sns_topic" "this" {
  name              = var.topic_name
  display_name      = var.display_name
  kms_master_key_id = var.kms_master_key_id

  tags = var.tags
}

resource "aws_sns_topic_policy" "this" {
  count  = length(var.allowed_publish_arns) > 0 ? 1 : 0
  arn    = aws_sns_topic.this.arn
  policy = data.aws_iam_policy_document.sns_policy.json
}

data "aws_iam_policy_document" "sns_policy" {
  statement {
    effect = "Allow"
    actions = ["sns:Publish"]
    resources = [aws_sns_topic.this.arn]
    principals {
      type        = "AWS"
      identifiers = var.allowed_publish_arns
    }
  }
}

resource "aws_sns_topic_subscription" "this" {
  for_each  = { for idx, sub in var.subscriptions : idx => sub }

  topic_arn = aws_sns_topic.this.arn
  protocol  = each.value.protocol
  endpoint  = each.value.endpoint

  redrive_policy = each.value.dlq_arn != null ? jsonencode({
    deadLetterTargetArn = each.value.dlq_arn
  }) : null
}

