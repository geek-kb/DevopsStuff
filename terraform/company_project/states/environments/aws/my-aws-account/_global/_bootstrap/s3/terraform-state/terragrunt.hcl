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

  assignment_prefix = "aidoc-devops2-ex"
}

terraform {
  source = "${get_repo_root()}/terraform/modules/s3"
}

dependency "kms-terraform-state-key" {
  config_path = "../../kms/terraform-state-key"

  mock_outputs = {
    key_arn = "(known after apply)"
  }
}

inputs = {
  bucket_name   = "${local.assignment_prefix}-${local.parent_folder_name}"
  versioning    = true
  force_destroy = false
  encryption    = true
  kms_key_arn   = dependency.kms-terraform-state-key.outputs.key_arn

  lifecycle_rules = [
    {
      id     = "delete-old-versions"
      status = "Enabled"
    }
  ]


  tags = {
    Environment = "bootstrap"
    Project     = "ordering-system"
  }
}
