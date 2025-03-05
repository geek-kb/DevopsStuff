include {
  path = find_in_parent_folders()
}

locals {
  account_vars     = read_terragrunt_config(find_in_parent_folders("account.hcl"))
  region_vars      = read_terragrunt_config(find_in_parent_folders("region.hcl"))
  environment_vars = read_terragrunt_config(find_in_parent_folders("env.hcl"))

  account_name     = local.account_vars.locals.account_name
  account_id       = local.account_vars.locals.account_id
  region           = local.region_vars.locals.region
  environment      = local.environment_vars.locals.environment
  environment_name = local.environment_vars.locals.environment_name

  parent_folder_path  = split("/", path_relative_to_include())
  parent_folder_index = length(local.parent_folder_path) - 1
  parent_folder_name  = element(local.parent_folder_path, local.parent_folder_index)

  triggering_bucket_name             = "ordering-system"
  bucket_directory_and_db_table_name = "orders"
  sqs_queue_name                     = "order-processor"
  function_name                      = "order_verification"

  assignment_prefix = "aidoc-devops2-ex"
}

terraform {
  source = "${get_repo_root()}/terraform/modules/iam-role"
}

dependency "s3_trigger_bucket" {
  config_path = "../../s3/${local.triggering_bucket_name}"

  mock_outputs = {
    s3_bucket_arn = "arn:aws:s3:::${local.triggering_bucket_name}"
  }
}

dependency "sqs_queue" {
  config_path = "../../sqs/${local.sqs_queue_name}"

  mock_outputs = {
    sqs_queue_arn = "arn:aws:sqs:${local.region}:${local.account_id}:${local.sqs_queue_name}"
  }
}

dependency "dynamodb_table" {
  config_path = "../../dynamodb/${local.bucket_directory_and_db_table_name}"

  mock_outputs = {
    table_arn = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${local.bucket_directory_and_db_table_name}"
  }
}

inputs = {
  role_name = "${local.assignment_prefix}-${local.parent_folder_name}"

  max_session_duration = 14400

  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "lambda.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })

  inline_policies_to_attach = {
    # Restrict SQS Access to only send messages to the order processor queue
    SQSSendMessage = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "sqs:SendMessage"
          ],
          "Resource" : "${dependency.sqs_queue.outputs.sqs_queue_arn}"
        }
      ]
    },

    # Restrict S3 access to only read from the specific bucket
    S3ReadAccess = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "s3:GetObject",
            "s3:ListBucket"
          ],
          "Resource" : [
            "${dependency.s3_trigger_bucket.outputs.s3_bucket_arn}",
            "${dependency.s3_trigger_bucket.outputs.s3_bucket_arn}/*"
          ]
        }
      ]
    },

    # Restrict DynamoDB access to only read data from the orders table
    DynamoDBReadAccess = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "dynamodb:GetItem",
            "dynamodb:Query",
            "dynamodb:Scan"
          ],
          "Resource" : "${dependency.dynamodb_table.outputs.table_arn}"
        }
      ]
    },

    # Lambda CloudWatch Logging permissions
    LambdaCloudWatch = {
      "Version" : "2012-10-17",
      "Statement" : [
        {
          "Effect" : "Allow",
          "Action" : [
            "logs:CreateLogGroup",
            "logs:CreateLogStream",
            "logs:PutLogEvents"
          ],
          "Resource" : "arn:aws:logs:${local.region}:${local.account_id}:log-group:/aws/lambda/${local.function_name}:*"
        }
      ]
    }
  }

  tags = {
    Environment = local.environment
    Project     = "ordering-system"
  }
}
