output "state_machine_arns" {
  description = "ARNs de las Step Functions creadas."
  value       = { for sf_key, sf in aws_sfn_state_machine.this : sf_key => sf.arn }
}

output "state_machine_names" {
  description = "Nombres de las Step Functions creadas."
  value       = { for sf_key, sf in aws_sfn_state_machine.this : sf_key => sf.name }
}

output "glue_tables" {
  description = "Tablas Glue/Athena creadas por el modulo Athena."
  value = {
    for table_key, table in module.athena :
    table_key => {
      database_name = table.database_name
      table_name    = table.table_name
      s3_location   = table.s3_location
    }
  }
}
