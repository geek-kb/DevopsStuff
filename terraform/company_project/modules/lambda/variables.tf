variable "function_name" {
  description = "Name of the Lambda function. Must be unique within the region"
  type        = string
}

variable "iam_lambda_role_arn" {
  description = "ARN of the IAM role that the Lambda function will assume"
  type        = string
}

variable "handler" {
  description = "Function entrypoint in your code. Format: file_name.function_name"
  type        = string
  default     = "lambda_function.lambda_handler"
}

variable "runtime" {
  description = "Runtime environment for the Lambda function (e.g., python3.9)"
  type        = string
  default     = "python3.9"
}

variable "timeout" {
  description = "Amount of time your Lambda function has to run in seconds"
  type        = number
  default     = 60
}

variable "memory_size" {
  description = "Amount of memory in MB your Lambda function can use"
  type        = number
  default     = 128
}

variable "containerization" {
  description = "Whether to use container image instead of zip deployment package"
  type        = bool
  default     = false
}

variable "image_uri" {
  description = "URI of the container image when using containerization"
  type        = string
  default     = null
}

variable "enable_function_url" {
  description = "Whether to create a function URL for the Lambda function"
  type        = bool
  default     = false
}

variable "function_url_cors" {
  description = "CORS configuration for the function URL if enabled"
  type = object({
    allow_origins  = list(string)
    allow_methods  = list(string)
    allow_headers  = list(string)
    expose_headers = list(string)
    max_age        = number
  })
  default = null
}

variable "log_retention" {
  description = "Number of days to retain Lambda function logs in CloudWatch"
  type        = number
  default     = 7
}

variable "lambda_environment" {
  description = "Environment variables to pass to the Lambda function"
  type        = map(string)
  default     = {}
}

variable "enable_s3_trigger" {
  description = "Whether to create an S3 event trigger for the Lambda function"
  type        = bool
  default     = false
}

variable "s3_bucket_name" {
  description = "Name of the S3 bucket to use as trigger source"
  type        = string
  default     = ""
}

variable "s3_trigger_directory" {
  description = "Directory path in S3 bucket to monitor for events"
  type        = string
  default     = ""
}

variable "function_directory" {
  description = "Local directory containing Lambda function code"
  type        = string
  default     = ""
}

variable "function_zip_filename" {
  description = "Name of the zip file for the Lambda deployment package"
  type        = string
  default     = "lambda.zip"
}

variable "function_source_zip_path" {
  description = "Path to pre-existing zip file for Lambda deployment"
  type        = string
  default     = ""
}

variable "function_source_code_path" {
  description = "Path to Lambda function source code directory"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Map of tags to apply to all resources created by this module"
  type        = map(string)
  default     = {}
}
