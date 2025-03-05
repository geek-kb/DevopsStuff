resource "aws_lambda_function" "this" {
  function_name    = var.function_name
  role             = var.iam_lambda_role_arn
  handler          = var.containerization ? null : var.handler
  runtime          = var.containerization ? null : var.runtime
  timeout          = var.timeout
  memory_size      = var.memory_size
  package_type     = var.containerization ? "Image" : "Zip"
  image_uri        = var.containerization ? var.image_uri : null
  s3_bucket        = !var.containerization ? var.s3_bucket_name : null
  s3_key           = !var.containerization ? aws_s3_object.source-code-object[0].key : null
  source_code_hash = !var.containerization ? data.archive_file.source-code-zip[0].output_base64sha256 : null

  dynamic "environment" {
    for_each = length(var.lambda_environment) > 0 ? [1] : []
    content {
      variables = var.lambda_environment
    }
  }

  tags = var.tags
}

resource "aws_lambda_function_url" "this" {
  count              = var.enable_function_url ? 1 : 0
  function_name      = aws_lambda_function.this.function_name
  authorization_type = "NONE"

  dynamic "cors" {
    for_each = var.enable_function_url && length(var.function_url_cors) > 0 ? [1] : []
    content {
      allow_origins  = var.function_url_cors.allow_origins
      allow_methods  = var.function_url_cors.allow_methods
      allow_headers  = var.function_url_cors.allow_headers
      expose_headers = var.function_url_cors.expose_headers
      max_age        = var.function_url_cors.max_age
    }
  }
}

resource "aws_cloudwatch_log_group" "lambda" {
  name              = "/aws/lambda/${aws_lambda_function.this.function_name}"
  retention_in_days = var.log_retention
}

# S3 Code Upload Logic
data "archive_file" "source-code-zip" {
  count       = var.containerization ? 0 : 1
  type        = "zip"
  output_path = "${var.function_directory}/${var.function_zip_filename}"

  dynamic "source" {
    for_each = [for file in fileset("${var.function_source_code_path}/", "*") : file if file != "Dockerfile"]
    content {
      content  = file("${var.function_source_code_path}/${source.value}")
      filename = source.value
    }
  }
}

resource "aws_s3_object" "source-code-object" {
  count       = var.containerization ? 0 : 1
  bucket      = var.s3_bucket_name
  key         = var.function_zip_filename
  source      = data.archive_file.source-code-zip[0].output_path
  source_hash = data.archive_file.source-code-zip[0].output_base64sha256
  etag        = filemd5(var.function_source_zip_path)
}

# S3 Trigger Permissions
resource "aws_lambda_permission" "s3_trigger" {
  count                  = var.enable_s3_trigger ? 1 : 0
  statement_id           = "AllowS3Invoke"
  action                 = "lambda:InvokeFunction"
  function_name          = aws_lambda_function.this.function_name
  principal              = "s3.amazonaws.com"
  source_arn             = "arn:aws:s3:::${var.s3_bucket_name}"
  function_url_auth_type = "NONE"
}

resource "aws_s3_bucket_notification" "s3_trigger" {
  count  = var.enable_s3_trigger ? 1 : 0
  bucket = var.s3_bucket_name

  lambda_function {
    lambda_function_arn = aws_lambda_function.this.arn
    events              = ["s3:ObjectCreated:*"]
    filter_prefix       = var.s3_trigger_directory
  }
}
