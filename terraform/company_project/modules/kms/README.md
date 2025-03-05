# kms

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
| [aws_kms_alias.kms_key_alias](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_alias) | resource |
| [aws_kms_key.kms_key](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/kms_key) | resource |
| [aws_caller_identity.current](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/data-sources/caller_identity) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_key_rotation"></a> [enable\_key\_rotation](#input\_enable\_key\_rotation) | Enable automatic key rotation | `bool` | `true` | no |
| <a name="input_enable_multi_region"></a> [enable\_multi\_region](#input\_enable\_multi\_region) | Enable multi-region support for the KMS key | `bool` | `false` | no |
| <a name="input_key_spec"></a> [key\_spec](#input\_key\_spec) | The key spec for the KMS key (SYMMETRIC\_DEFAULT, RSA\_2048, etc.) | `string` | `"SYMMETRIC_DEFAULT"` | no |
| <a name="input_key_usage"></a> [key\_usage](#input\_key\_usage) | The cryptographic operations for which the key can be used (ENCRYPT\_DECRYPT, SIGN\_VERIFY, etc.) | `string` | `"ENCRYPT_DECRYPT"` | no |
| <a name="input_kms_key_alias"></a> [kms\_key\_alias](#input\_kms\_key\_alias) | Alias for the KMS key | `string` | n/a | yes |
| <a name="input_kms_policy"></a> [kms\_policy](#input\_kms\_policy) | JSON-encoded IAM policy for the KMS key (if empty, a default policy is used) | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the KMS key | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_key_alias"></a> [key\_alias](#output\_key\_alias) | The alias of the KMS key |
| <a name="output_key_arn"></a> [key\_arn](#output\_key\_arn) | The ARN of the KMS key |
| <a name="output_key_id"></a> [key\_id](#output\_key\_id) | The ID of the KMS key |
<!-- END_TF_DOCS -->
