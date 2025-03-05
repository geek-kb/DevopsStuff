# ssm

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
| [aws_ssm_parameter.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ssm_parameter) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_kms_key_id"></a> [kms\_key\_id](#input\_kms\_key\_id) | The KMS key id or arn for encrypting a SecureString | `string` | `"arn:aws:kms:eu-north-1:912466608750:key/00fc7f10-cd91-461e-84d3-0c679e709f53"` | no |
| <a name="input_prefix"></a> [prefix](#input\_prefix) | Prefix added to ssm parameter name | `string` | `""` | no |
| <a name="input_ssm_params"></a> [ssm\_params](#input\_ssm\_params) | Map of SSM parameters to create with their configurations | `map(string)` | `{}` | no |
| <a name="input_unencrypted_suffix"></a> [unencrypted\_suffix](#input\_unencrypted\_suffix) | Parameters with this suffix in the name will be saved as plaintext values. | `string` | `"_unencrypted"` | no |

## Outputs

No outputs.
<!-- END_TF_DOCS -->
