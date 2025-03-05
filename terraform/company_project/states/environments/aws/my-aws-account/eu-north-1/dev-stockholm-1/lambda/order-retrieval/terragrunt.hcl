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

  parent_folder_path            = split("/", path_relative_to_include())
  parent_folder_index           = length(local.parent_folder_path) - 1
  parent_folder_name            = element(local.parent_folder_path, local.parent_folder_index)
  current_folder                = basename(path_relative_to_include())
  parent_of_parent_folder_index = length(local.parent_folder_path) - 2
  service_name                  = element(local.parent_folder_path, local.parent_of_parent_folder_index)

  function_name             = "${replace("${local.parent_folder_name}", "-", "_")}"
  function_zip_filename     = "${local.function_name}_source_code.zip"
  function_directory        = "${get_repo_root()}/terraform/states/environments/aws/${path_relative_to_include()}"
  function_source_code_path = "${local.function_directory}/lambda_source_code"
  function_source_zip_path  = "${local.function_directory}/${local.function_zip_filename}"

  sops_file_path = "../../ssm/managed/params.yaml"
}

terraform {
  source = "${get_repo_root()}/terraform/modules/lambda"
}

dependency "iam_role" {
  config_path = "../../iam-role/retrieval_lambda_execution"

  mock_outputs = {
    arn = "arn:aws:iam::${local.account_id}:role/retrieval_lambda_execution"
  }
}

dependency "ecr_repository" {
  config_path = "../../ecr/${local.parent_folder_name}"

  mock_outputs = {
    repository_url = "${local.account_id}.dkr.ecr.${local.region}.amazonaws.com/${local.parent_folder_name}"
  }
}

dependency "sqs_queue" {
  config_path = "../../sqs/order-processor"

  mock_outputs = {
    sqs_queue_url = "https://sqs.${local.region}.amazonaws.com/${local.account_id}/order-processor"
  }
}

inputs = {
  function_name       = local.function_name
  iam_lambda_role_arn = "${dependency.iam_role.outputs.arn}"
  memory_size         = 128
  timeout             = 60
  containerization    = true
  image_uri           = "${dependency.ecr_repository.outputs.repository_url}:latest"


  enable_function_url = true
  function_url_cors = {
    allow_credentials = true
    allow_origins     = ["*"]
    allow_methods     = ["POST"]
    allow_headers     = ["x-api-key", "content-type"]
    expose_headers    = ["*"]
    max_age           = 86400
  }

  lambda_environment = {
    API_KEY_PARAMETER_NAME = "/dev-stockholm-1/lambda/order-retrieval/api_key"
    SQS_QUEUE_URL          = "${dependency.sqs_queue.outputs.sqs_queue_url}"
  }
}
