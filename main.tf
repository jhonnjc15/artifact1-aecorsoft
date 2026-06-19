locals {
  deploy_config = jsondecode(file("${path.module}/deploy.json"))

  enabled_step_functions = {
    for sf_key, sf_config in local.deploy_config.step_functions :
    sf_key => sf_config
    if try(sf_config.enabled, true)
  }

  enabled_athena_tables = {
    for table_key, table_config in try(local.deploy_config.athena, {}) :
    table_key => merge(
      table_config,
      {
        sql_path = abspath("${path.module}/${table_config.sql_path}")
      }
    )
    if try(table_config.enabled, true)
  }

  common_tags = {
    environment = local.deploy_config.environment
    managed_by  = "terraform"
    project     = "aecorsoft"
  }
}

resource "aws_sfn_state_machine" "this" {
  for_each = local.enabled_step_functions

  name     = each.value.name
  role_arn = var.step_function_role_arn

  definition = templatefile(
    abspath("${path.module}/${each.value.definition_path}"),
    {
      instance_id           = each.value.instance_id
      bucket                = each.value.bucket
      athena_results_bucket = each.value.athena_results_bucket
      base_path             = each.value.base_path
      database_name         = each.value.database_name
      table_name            = each.value.table_name
      wait_seconds          = each.value.wait_seconds
      commands_json         = jsonencode(each.value.commands)
    }
  )

  tags = local.common_tags
}

module "athena" {
  for_each = local.enabled_athena_tables
  source   = "git::https://github.com/jhonnjc15/artifact3-terraform-templates.git//modules/athena?ref=main"

  athena = each.value
  tags   = local.common_tags
}
