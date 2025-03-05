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

  assignment_prefix    = "aidoc-devops2-ex"
  lambda_function_name = "order_retrieval"
  repos_list           = ["geek-kb/aidoc_assignment"]
}

terraform {
  source = "${get_repo_root()}/terraform/modules/iam-role"
}

dependency "github_oidc_auth_role" {
  config_path = "../github-oidc-auth"
}

inputs = {
  role_name = "${local.assignment_prefix}-${local.parent_folder_name}"

  max_session_duration = 14400

  assume_role_policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "AWS": [
          "${dependency.github_oidc_auth_role.outputs.arn}"
        ]
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

  inline_policies_to_attach = {
    iam_access = {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "iam:GetRole",
            "iam:ListRolePolicies",
            "iam:GetRolePolicy",
            "iam:ListAttachedRolePolicies"
          ],
          Resource = [
            "*"
          ]
        }
      ]
    },
    CloudWatchLogs = {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "logs:*"
          ],
          Resource = [
            "arn:aws:logs:${local.region}:${local.account_id}:*",
          ]
        }
      ]
    },
    Lambda = {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "lambda:GetFunction",
            "lambda:InvokeFunction",
            "lambda:ListFunctions",
            "lambda:ListTags",
            "lambda:ListVersionsByFunction",
            "lambda:PublishVersion",
            "lambda:UpdateFunctionCode",
            "lambda:UpdateFunctionConfiguration",
            "lambda:GetFunctionUrlConfig",
            "lambda:CreateFunctionUrlConfig",
            "lambda:DeleteFunctionUrlConfig",
            "lambda:UpdateFunctionUrlConfig",
            "lambda:GetFunctionEventInvokeConfig",
            "lambda:GetFunctionConcurrency"
          ],
          Resource = [
            "arn:aws:lambda:${local.region}:${local.account_id}:function:${local.lambda_function_name}"
          ]
        }
      ]
    },
    S3Access = {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "s3:PutObject",
            "s3:GetObject",
            "s3:ListBucket",
            "s3:GetBucketVersioning",
            "s3:GetBucketPolicy"
          ],
          Resource = [
            "arn:aws:s3:::ordering-system",
            "arn:aws:s3:::ordering-system/*",
            "arn:aws:s3:::order-verification-code",
            "arn:aws:s3:::order-verification-code/*"
          ]
        }
      ]
    },
    ECRAccess = {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "ecr:GetAuthorizationToken",
            "ecr:BatchCheckLayerAvailability",
            "ecr:GetDownloadUrlForLayer",
            "ecr:GetRepositoryPolicy",
            "ecr:DescribeRepositories",
            "ecr:ListImages",
            "ecr:DescribeImages",
            "ecr:BatchGetImage",
            "ecr:InitiateLayerUpload",
            "ecr:UploadLayerPart",
            "ecr:CompleteLayerUpload",
            "ecr:PutImage",
            "ecr:ListTagsForResource",
            "ecr:GetLifecyclePolicy"
          ],
          Resource = [
            "*"
          ]
        }
      ]
    },
    terraform_state_access = {
      Version = "2012-10-17",
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "s3:ListBucket",
            "s3:GetObject",
            "s3:PutObject",
            "s3:GetBucketVersioning",
            "s3:GetBucketPolicy",
            "s3:GetBucketPublicAccessBlock",
            "s3:PutEncryptionConfiguration",
            "dynamodb:GetItem",
            "dynamodb:PutItem",
            "dynamodb:DeleteItem",
            "dynamodb:DescribeTable",
            "kms:Decrypt",
            "kms:DescribeKey",
            "kms:Encrypt",
            "kms:GenerateDataKey"
          ],
          Resource = [
            "arn:aws:s3:::${local.assignment_prefix}-terraform-state",
            "arn:aws:s3:::${local.assignment_prefix}-terraform-state/*",
            "arn:aws:dynamodb:${local.region}:${local.account_id}:table/${local.assignment_prefix}-terraform-state-locks",
            "arn:aws:kms:${local.region}:${local.account_id}:key/3beb74d1-90ae-4b5a-a205-fd043c751bba",
            "arn:aws:kms:${local.region}:${local.account_id}:key/00fc7f10-cd91-461e-84d3-0c679e709f53"
          ]
        }
      ]
    },
    sqs_access = {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "sqs:GetQueueAttributes",
            "sqs:listqueuetags"
          ],
          Resource = [
            "arn:aws:sqs:${local.region}:${local.account_id}:order-processor"
          ]
        }
      ]
    },
    ssm_and_kms_access = {
      Version = "2012-10-17"
      Statement = [
        {
          Effect = "Allow",
          Action = [
            "ssm:GetParameter",
            "ssm:PutParameter",
            "ssm:DeleteParameter",
            "ssm:DescribeParameters"
          ],
          Resource = [
            "arn:aws:ssm:${local.region}:${local.account_id}:parameter/dev-stockholm-1/*"
          ]
        },
        {
          Effect = "Allow",
          Action = [
            "kms:Decrypt",
            "kms:DescribeKey"
          ],
          Resource = [
            "arn:aws:kms:${local.region}:${local.account_id}:alias/bootstrap/sops-key"
          ]
        }
      ]
    }
  }
  tags = {
    Environment = local.environment_name
    Project     = "ordering-system"
  }
}
