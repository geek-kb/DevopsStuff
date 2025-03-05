resource "aws_iam_role" "this" {
  count = var.create_iam_role ? 1 : 0

  name                 = var.role_name
  assume_role_policy   = var.assume_role_policy
  max_session_duration = var.max_session_duration
  tags                 = var.tags
}

resource "aws_iam_role_policy_attachment" "managed" {
  for_each   = toset(var.managed_iam_policies_to_attach)
  role       = aws_iam_role.this[0].name
  policy_arn = each.key
}

resource "aws_iam_role_policy" "inline" {
  for_each = var.inline_policies_to_attach

  name   = each.key
  role   = aws_iam_role.this[0].name
  policy = jsonencode(each.value)
}

resource "aws_iam_role_policy" "kms_access" {
  for_each = var.kms_policies_to_attach

  name   = each.key
  role   = aws_iam_role.this[0].name
  policy = jsonencode(each.value)
}
