terraform_version_constraint = "= 1.5.5"

locals {
  account_name = "my-aws-account"
  account_id   = "912466608750"
  region       = "eu-north-1"

  assignment_prefix = "aidoc-devops2-ex"

  common_vars = {
    assignment_prefix = local.assignment_prefix
    account_id        = local.account_id
    account_name      = local.account_name
    region            = local.region
  }
}

remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "${local.assignment_prefix}-terraform-state"
    key            = "${path_relative_to_include()}/terraform.tfstate"
    region         = "${local.region}"
    encrypt        = true
    kms_key_id     = "arn:aws:kms:${local.region}:${local.account_id}:alias/bootstrap/${local.assignment_prefix}-terraform-state-key"
    dynamodb_table = "${local.assignment_prefix}-terraform-state-locks"

    s3_bucket_tags = {
      Environment = "bootstrap"
      Project     = "ordering-system"
    }
  }
}

#generate "provider" {
#  path      = "provider.tf"
#  if_exists = "overwrite_terragrunt"
#  contents  = <<EOF
#terraform {
#  required_providers {
#    aws = {
#      source  = "hashicorp/aws"
#      version = ">= 5.84.0, < 6.0.0"
#    }
#    sops = {
#      source  = "carlpett/sops"
#      version = ">= 0.7.2"
#    }
#  }
#}
#provider "aws" {
#  region = "${local.region}"
#}
#provider "sops" {}
#EOF
#}

inputs = local.common_vars
