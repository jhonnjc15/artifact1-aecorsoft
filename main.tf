locals {
  deploy_config = jsondecode(file("${path.module}/deploy.json"))
  environments  = ["dev", "qas", "prd"]

  raw_step_functions = try(local.deploy_config.step_functions, {})
  raw_athena_tables  = try(local.deploy_config.athena, {})

  enabled_step_functions = {
    for sf_key, sf_config in local.raw_step_functions :
    sf_key => sf_config
    if try(sf_config.enabled, true) && contains(try(sf_config.enabled_environments, local.environments), var.environment)
  }

  step_function_environment_values = {
    for sf_key, sf_config in local.enabled_step_functions :
    sf_key => try(sf_config.environment_values[var.environment], {})
  }

  step_function_s3_parts = {
    for sf_key, environment_values in local.step_function_environment_values :
    sf_key => try(regex("^s3://([^/]+)/(.*)$", trimsuffix(trimspace(environment_values.s3_location), "/")), [])
  }

  athena_table_step_function_keys = {
    for table_key, table_config in local.raw_athena_tables :
    table_key => try([
      for sf_key, sf_config in local.enabled_step_functions :
      sf_key
      if try(sf_config.athena_table_key, null) == table_key
    ][0], null)
  }

  enabled_athena_tables = {
    for table_key, table_config in local.raw_athena_tables :
    table_key => merge(
      table_config,
      {
        sql_path      = abspath("${path.module}/${table_config.sql_path}")
        database_name = try(trimspace(table_config.database_name), "") != "" ? trimspace(table_config.database_name) : null
        s3_location = try(trimspace(table_config.s3_location), "") != "" ? trimspace(table_config.s3_location) : (
          local.athena_table_step_function_keys[table_key] != null
          ? local.step_function_environment_values[local.athena_table_step_function_keys[table_key]].s3_location
          : null
        )
      }
    )
    if try(table_config.enabled, true) && contains(try(table_config.enabled_environments, local.environments), var.environment)
  }

  common_tags = {
    environment = var.environment
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
      instance_id           = local.step_function_environment_values[each.key].instance_id
      bucket                = local.step_function_s3_parts[each.key][0]
      athena_results_bucket = local.step_function_environment_values[each.key].athena_results_bucket
      base_path             = "${local.step_function_s3_parts[each.key][1]}/"
      database_name         = each.value.database_name
      table_name            = each.value.table_name
      wait_seconds          = each.value.wait_seconds
      commands_json         = jsonencode(each.value.commands)
      parser_lambda_arn     = local.step_function_environment_values[each.key].parser_lambda_arn
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
