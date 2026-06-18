locals {
  deploy_config = jsondecode(file("${path.module}/deploy.json"))
  sf_config     = local.deploy_config.step_function
  common_tags = {
    environment = local.deploy_config.environment
    managed_by  = "terraform"
    project     = "aecorsoft"
  }
}

resource "aws_sfn_state_machine" "this" {
  name     = local.sf_config.name
  role_arn = var.step_function_role_arn

  definition = templatefile(
    abspath("${path.module}/src/state_machine/aecorsoft_sfn.json"),
    {
      instance_id          = local.sf_config.instance_id
      bucket               = local.sf_config.bucket
      athena_results_bucket = local.sf_config.athena_results_bucket
      base_path            = local.sf_config.base_path
      database_name        = local.sf_config.database_name
      table_name           = local.sf_config.table_name
      wait_seconds         = local.sf_config.wait_seconds
      commands_json        = jsonencode(local.sf_config.commands)
    }
  )

  tags = local.common_tags
}
