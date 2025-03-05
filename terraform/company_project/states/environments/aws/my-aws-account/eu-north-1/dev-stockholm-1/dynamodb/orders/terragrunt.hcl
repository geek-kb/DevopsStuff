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
}

terraform {
  source = "${get_repo_root()}/terraform/modules/dynamodb"
}

inputs = {
  table_name       = "${local.parent_folder_name}"
  stream_enabled   = true
  stream_view_type = "NEW_IMAGE"
  billing_mode     = "PAY_PER_REQUEST"
  hash_key         = "partitionKey"
  range_key        = "sortKey"

  attributes = [
    {
      name = "partitionKey"
      type = "S"
    },
    {
      name = "sortKey"
      type = "S"
    },
    {
      name = "orderId"
      type = "S"
    }
  ]

  # Ensuring `orderId` is indexed as part of the GSI
  global_secondary_indexes = [
    {
      name            = "OrderIndex"
      hash_key        = "orderId"
      range_key       = "sortKey"
      projection_type = "ALL"
    }
  ]
}
