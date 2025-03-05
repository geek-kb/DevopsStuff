# dynamodb

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
| [aws_dynamodb_table.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/dynamodb_table) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_attributes"></a> [attributes](#input\_attributes) | List of attributes for the table | <pre>list(object({<br/>    name = string<br/>    type = string<br/>  }))</pre> | `[]` | no |
| <a name="input_billing_mode"></a> [billing\_mode](#input\_billing\_mode) | Billing mode for the table (PAY\_PER\_REQUEST or PROVISIONED) | `string` | `"PAY_PER_REQUEST"` | no |
| <a name="input_global_secondary_indexes"></a> [global\_secondary\_indexes](#input\_global\_secondary\_indexes) | List of global secondary indexes (GSIs) | <pre>list(object({<br/>    name            = string<br/>    hash_key        = string<br/>    range_key       = optional(string)<br/>    projection_type = string<br/>  }))</pre> | `[]` | no |
| <a name="input_hash_key"></a> [hash\_key](#input\_hash\_key) | The attribute name for the hash key | `string` | n/a | yes |
| <a name="input_local_secondary_indexes"></a> [local\_secondary\_indexes](#input\_local\_secondary\_indexes) | List of local secondary indexes (LSIs) | <pre>list(object({<br/>    name            = string<br/>    range_key       = string<br/>    projection_type = string<br/>  }))</pre> | `[]` | no |
| <a name="input_point_in_time_recovery_enabled"></a> [point\_in\_time\_recovery\_enabled](#input\_point\_in\_time\_recovery\_enabled) | Enable point-in-time recovery for the table | `bool` | `false` | no |
| <a name="input_range_key"></a> [range\_key](#input\_range\_key) | The attribute name for the range key (if applicable) | `string` | `null` | no |
| <a name="input_server_side_encryption_enabled"></a> [server\_side\_encryption\_enabled](#input\_server\_side\_encryption\_enabled) | Enable server-side encryption | `bool` | `false` | no |
| <a name="input_server_side_encryption_kms_key_arn"></a> [server\_side\_encryption\_kms\_key\_arn](#input\_server\_side\_encryption\_kms\_key\_arn) | KMS key ARN for encryption (required if encryption is enabled) | `string` | `null` | no |
| <a name="input_table_name"></a> [table\_name](#input\_table\_name) | The name of the DynamoDB table | `string` | n/a | yes |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags for the DynamoDB table | `map(string)` | `{}` | no |
| <a name="input_ttl_attribute_name"></a> [ttl\_attribute\_name](#input\_ttl\_attribute\_name) | The name of the TTL attribute | `string` | `null` | no |
| <a name="input_ttl_enabled"></a> [ttl\_enabled](#input\_ttl\_enabled) | Enable TTL for the table | `bool` | `false` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_table_arn"></a> [table\_arn](#output\_table\_arn) | The ARN of the DynamoDB table |
| <a name="output_table_name"></a> [table\_name](#output\_table\_name) | The name of the DynamoDB table |
<!-- END_TF_DOCS -->
