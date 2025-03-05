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

  project_name      = "ordering-system"
  assignment_prefix = "aidoc-devops2-ex"
}

terraform {
  source = "${get_repo_root()}/terraform/modules/kms"
}

dependency "iam-role-admin" {
  config_path = "../../../admin/iam-role/admin/"

}

inputs = {
  kms_key_alias = "${local.environment_name}/${local.assignment_prefix}-terraform-state-key"

  kms_admins = [
    "arn:aws:iam::${local.account_id}:user/itaig"
  ]

  sops_roles = [] # GitHub Actions IAM role will be added AFTER creation

  tags = {
    Environment = local.environment_name
    Project     = local.project_name
  }
}
