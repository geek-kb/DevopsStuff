resource "aws_ssm_parameter" "this" {
  for_each = var.ssm_params

  name   = format("%s%s", var.prefix, trimsuffix(each.key, var.unencrypted_suffix))
  type   = length(regexall(".*${var.unencrypted_suffix}", each.key)) > 0 ? "String" : "SecureString"
  value  = each.value
  key_id = length(regexall(".*${var.unencrypted_suffix}", each.key)) > 0 ? null : var.kms_key_id
}
