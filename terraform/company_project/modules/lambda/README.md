# lambda

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.0.0 |
| <a name="requirement_archive"></a> [archive](#requirement\_archive) | >= 2.0.0 |
| <a name="requirement_aws"></a> [aws](#requirement\_aws) | >= 4.0.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_archive"></a> [archive](#provider\_archive) | >= 2.0.0 |
| <a name="provider_aws"></a> [aws](#provider\_aws) | >= 4.0.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [aws_cloudwatch_log_group.lambda](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudwatch_log_group) | resource |
| [aws_lambda_function.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function) | resource |
| [aws_lambda_function_url.this](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_function_url) | resource |
| [aws_lambda_permission.s3_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/lambda_permission) | resource |
| [aws_s3_bucket_notification.s3_trigger](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_bucket_notification) | resource |
| [aws_s3_object.source-code-object](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/s3_object) | resource |
| [archive_file.source-code-zip](https://registry.terraform.io/providers/hashicorp/archive/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_containerization"></a> [containerization](#input\_containerization) | Whether to use container image instead of zip deployment package | `bool` | `false` | no |
| <a name="input_enable_function_url"></a> [enable\_function\_url](#input\_enable\_function\_url) | Whether to create a function URL for the Lambda function | `bool` | `false` | no |
| <a name="input_enable_s3_trigger"></a> [enable\_s3\_trigger](#input\_enable\_s3\_trigger) | Whether to create an S3 event trigger for the Lambda function | `bool` | `false` | no |
| <a name="input_function_directory"></a> [function\_directory](#input\_function\_directory) | Local directory containing Lambda function code | `string` | `""` | no |
| <a name="input_function_name"></a> [function\_name](#input\_function\_name) | Name of the Lambda function. Must be unique within the region | `string` | n/a | yes |
| <a name="input_function_source_code_path"></a> [function\_source\_code\_path](#input\_function\_source\_code\_path) | Path to Lambda function source code directory | `string` | `""` | no |
| <a name="input_function_source_zip_path"></a> [function\_source\_zip\_path](#input\_function\_source\_zip\_path) | Path to pre-existing zip file for Lambda deployment | `string` | `""` | no |
| <a name="input_function_url_cors"></a> [function\_url\_cors](#input\_function\_url\_cors) | CORS configuration for the function URL if enabled | <pre>object({<br/>    allow_origins  = list(string)<br/>    allow_methods  = list(string)<br/>    allow_headers  = list(string)<br/>    expose_headers = list(string)<br/>    max_age        = number<br/>  })</pre> | `null` | no |
| <a name="input_function_zip_filename"></a> [function\_zip\_filename](#input\_function\_zip\_filename) | Name of the zip file for the Lambda deployment package | `string` | `"lambda.zip"` | no |
| <a name="input_handler"></a> [handler](#input\_handler) | Function entrypoint in your code. Format: file\_name.function\_name | `string` | `"lambda_function.lambda_handler"` | no |
| <a name="input_iam_lambda_role_arn"></a> [iam\_lambda\_role\_arn](#input\_iam\_lambda\_role\_arn) | ARN of the IAM role that the Lambda function will assume | `string` | n/a | yes |
| <a name="input_image_uri"></a> [image\_uri](#input\_image\_uri) | URI of the container image when using containerization | `string` | `null` | no |
| <a name="input_lambda_environment"></a> [lambda\_environment](#input\_lambda\_environment) | Environment variables to pass to the Lambda function | `map(string)` | `{}` | no |
| <a name="input_log_retention"></a> [log\_retention](#input\_log\_retention) | Number of days to retain Lambda function logs in CloudWatch | `number` | `7` | no |
| <a name="input_memory_size"></a> [memory\_size](#input\_memory\_size) | Amount of memory in MB your Lambda function can use | `number` | `128` | no |
| <a name="input_runtime"></a> [runtime](#input\_runtime) | Runtime environment for the Lambda function (e.g., python3.9) | `string` | `"python3.9"` | no |
| <a name="input_s3_bucket_name"></a> [s3\_bucket\_name](#input\_s3\_bucket\_name) | Name of the S3 bucket to use as trigger source | `string` | `""` | no |
| <a name="input_s3_trigger_directory"></a> [s3\_trigger\_directory](#input\_s3\_trigger\_directory) | Directory path in S3 bucket to monitor for events | `string` | `""` | no |
| <a name="input_tags"></a> [tags](#input\_tags) | Map of tags to apply to all resources created by this module | `map(string)` | `{}` | no |
| <a name="input_timeout"></a> [timeout](#input\_timeout) | Amount of time your Lambda function has to run in seconds | `number` | `60` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_lambda_arn"></a> [lambda\_arn](#output\_lambda\_arn) | ARN of the Lambda function |
| <a name="output_lambda_function_url"></a> [lambda\_function\_url](#output\_lambda\_function\_url) | URL of the Lambda function if function URL is enabled |
| <a name="output_lambda_invoke_arn"></a> [lambda\_invoke\_arn](#output\_lambda\_invoke\_arn) | Invoke ARN of the Lambda function |
<!-- END_TF_DOCS -->
