# ecr

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
| [aws_ecr_lifecycle_policy.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_lifecycle_policy) | resource |
| [aws_ecr_repository.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/ecr_repository) | resource |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_enable_kms_encryption"></a> [enable\_kms\_encryption](#input\_enable\_kms\_encryption) | Enable encryption using a customer-managed KMS key (true/false). | `bool` | `false` | no |
| <a name="input_image_tag_mutability"></a> [image\_tag\_mutability](#input\_image\_tag\_mutability) | The tag mutability setting for the repository (MUTABLE or IMMUTABLE). | `string` | `"MUTABLE"` | no |
| <a name="input_kms_key_arn"></a> [kms\_key\_arn](#input\_kms\_key\_arn) | KMS Key ARN for encryption at rest (only used if `enable_kms_encryption` is true). | `string` | `""` | no |
| <a name="input_lifecycle_policy"></a> [lifecycle\_policy](#input\_lifecycle\_policy) | Lifecycle policy for image retention in the repository. | `map(any)` | <pre>{<br/>  "rules": [<br/>    {<br/>      "action": {<br/>        "type": "expire"<br/>      },<br/>      "description": "Expire untagged images older than 30 days",<br/>      "rulePriority": 1,<br/>      "selection": {<br/>        "countNumber": 30,<br/>        "countType": "sinceImagePushed",<br/>        "countUnit": "days",<br/>        "tagStatus": "untagged"<br/>      }<br/>    }<br/>  ]<br/>}</pre> | no |
| <a name="input_repository_name"></a> [repository\_name](#input\_repository\_name) | Name of the ECR repository. | `string` | n/a | yes |
| <a name="input_scan_on_push"></a> [scan\_on\_push](#input\_scan\_on\_push) | Enable or disable image scanning on push. | `bool` | `true` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Tags to apply to the ECR repository. | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_repository_arn"></a> [repository\_arn](#output\_repository\_arn) | ARN of the ECR repository. |
| <a name="output_repository_url"></a> [repository\_url](#output\_repository\_url) | URL of the ECR repository. |
<!-- END_TF_DOCS -->
