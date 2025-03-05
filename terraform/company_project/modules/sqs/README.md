# sqs

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_sqs_queue.dead_letter](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue) | resource |
| [aws_sqs_queue_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/sqs_queue_policy) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_content_based_deduplication"></a> [content\_based\_deduplication](#input\_content\_based\_deduplication) | Enables content-based deduplication for FIFO queues | `bool` | `false` | no |
| <a name="input_dead_letter_queue_name"></a> [dead\_letter\_queue\_name](#input\_dead\_letter\_queue\_name) | The name of the dead-letter queue (required if enable\_dead\_letter\_queue = true) | `string` | `""` | no |
| <a name="input_delay_seconds"></a> [delay\_seconds](#input\_delay\_seconds) | The delay for messages arriving in the queue (in seconds) | `number` | `0` | no |
| <a name="input_enable_dead_letter_queue"></a> [enable\_dead\_letter\_queue](#input\_enable\_dead\_letter\_queue) | Enable a dead-letter queue for the SQS queue | `bool` | `false` | no |
| <a name="input_enable_encryption"></a> [enable\_encryption](#input\_enable\_encryption) | Enable encryption for the queue using KMS | `bool` | `false` | no |
| <a name="input_fifo_queue"></a> [fifo\_queue](#input\_fifo\_queue) | Set to true to create a FIFO queue | `bool` | `false` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | KMS key ARN for encryption (required if enable\_encryption = true) | `string` | `""` | no |
| <a name="input_max_message_size"></a> [max\_message\_size](#input\_max\_message\_size) | The maximum message size for the queue (in bytes) | `number` | `262144` | no |
| <a name="input_max_receive_count"></a> [max\_receive\_count](#input\_max\_receive\_count) | The number of times a message is delivered before moving to the dead-letter queue | `number` | `5` | no |
| <a name="input_message_retention_seconds"></a> [message\_retention\_seconds](#input\_message\_retention\_seconds) | The message retention period for the queue (in seconds) | `number` | `345600` | no |
| <a name="input_queue_name"></a> [queue\_name](#input\_queue\_name) | Name of the SQS queue | `string` | n/a | yes |
| <a name="input_queue_policy"></a> [queue\_policy](#input\_queue\_policy) | JSON-encoded IAM policy for the SQS queue | `string` | `""` | no |
| <a name="input_receive_wait_time_seconds"></a> [receive\_wait\_time\_seconds](#input\_receive\_wait\_time\_seconds) | The amount of time that a ReceiveMessage call waits for a message to arrive (in seconds) | `number` | `0` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the SQS queue | `map(string)` | `{}` | no |
| <a name="input_visibility_timeout_seconds"></a> [visibility\_timeout\_seconds](#input\_visibility\_timeout\_seconds) | The visibility timeout for the queue (in seconds) | `number` | `30` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_dead_letter_queue_arn"></a> [dead\_letter\_queue\_arn](#output\_dead\_letter\_queue\_arn) | ARN of the dead-letter queue (if enabled) |
| <a name="output_sqs_queue_arn"></a> [sqs\_queue\_arn](#output\_sqs\_queue\_arn) | ARN of the SQS queue |
| <a name="output_sqs_queue_id"></a> [sqs\_queue\_id](#output\_sqs\_queue\_id) | ID (name) of the SQS queue |
| <a name="output_sqs_queue_url"></a> [sqs\_queue\_url](#output\_sqs\_queue\_url) | ID (name) of the SQS queue |
<!-- END_TF_DOCS -->
