# iam-role

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | 5.84.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_iam_role.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role) | resource |
| [aws_iam_role_policy.inline](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy.kms_access](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy) | resource |
| [aws_iam_role_policy_attachment.managed](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/iam_role_policy_attachment) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_assume_role_policy"></a> [assume\_role\_policy](#input\_assume\_role\_policy) | JSON formatted policy document that controls which entities can assume this role | `string` | `null` | no |
| <a name="input_create_iam_role"></a> [create\_iam\_role](#input\_create\_iam\_role) | Whether to create the IAM role. Set to false to prevent role creation | `bool` | `true` | no |
| <a name="input_inline_policies_to_attach"></a> [inline\_policies\_to\_attach](#input\_inline\_policies\_to\_attach) | Map of inline IAM policies to attach to the role. Each element is a policy document | `any` | `{}` | no |
| <a name="input_kms_policies_to_attach"></a> [kms\_policies\_to\_attach](#input\_kms\_policies\_to\_attach) | Map of KMS policies to attach to the IAM role. Controls access to KMS keys | `map(any)` | `{}` | no |
| <a name="input_managed_iam_policies_to_attach"></a> [managed\_iam\_policies\_to\_attach](#input\_managed\_iam\_policies\_to\_attach) | List of managed IAM policy ARNs to attach to the role | `list(any)` | `[]` | no |
| <a name="input_max_session_duration"></a> [max\_session\_duration](#input\_max\_session\_duration) | Maximum session duration in seconds for the role. Valid values between 3600 and 43200 | `number` | `null` | no |
| <a name="input_role_name"></a> [role\_name](#input\_role\_name) | Name of the IAM role to create. Must be unique within the AWS account | `string` | `null` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to assign to the IAM role. Key-value pairs for resource organization | `map(string)` | n/a | yes |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_arn"></a> [arn](#output\_arn) | The ARN of the IAM role |
| <a name="output_id"></a> [id](#output\_id) | The IAM Role name |
<!-- END_TF_DOCS -->
