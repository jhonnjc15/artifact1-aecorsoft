# artifact1-aecorsoft

**Artefacto 1** — Integracion Aecorsoft con AWS Step Functions.

## Arquitectura

```
Orquestador (Artefacto 2)
    │
    ▼
Step Function Aecorsoft
    │
    ├── RunScript
    │   └── aws-sdk:ssm:sendCommand → EC2 ejecuta CLI Aecorsoft
    │
    ├── WaitOutput (N segundos)
    │
    ├── ValidateS3Output
    │   └── aws-sdk:s3:listObjectsV2
    │
    ├── CheckIfDataArrived  ← loop si KeyCount = 0
    │
    └── AddPartitionAthena
        └── aws-sdk:athena:startQueryExecution → ADD PARTITION
```

La tabla Glue/Athena se gestiona durante el despliegue usando el modulo
`athena` del repositorio `artifact3-terraform-templates`. La Step Function solo
agrega particiones durante cada ejecucion.

## Estructura

```
artifact1-aecorsoft/
├── deploy.json
├── main.tf
├── variables.tf
├── outputs.tf
├── versions.tf
├── backend.tf
├── terraform.tfvars.example
├── .github/workflows/terraform-dev.yml
└── src/
    ├── state_machine/aecorsoft_sfn.json
    └── sql/create_table_aecorsoft.sql
```

## Despliegue

1. Crear repo `artifact1-aecorsoft` en GitHub
2. Subir el codigo
3. Configurar secrets en GitHub Actions:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`
   - `STEP_FUNCTION_ROLE_ARN`
4. Editar `deploy.json` con valores reales
5. Ir a Actions → `Terraform dev - Artifact 1 Aecorsoft` → Run workflow

## Manifest `deploy.json`

El manifiesto separa la orquestacion (`step_functions`) de la creacion de tablas
(`athena`), siguiendo el patron del repo `artifact3-demo-consumer`.

```json
{
  "environment": "dev",
  "step_functions": {
    "aecorsoft_integration": {
      "enabled": true,
      "name": "sf-aecorsoft-integration-dev",
      "definition_path": "./src/state_machine/aecorsoft_sfn.json",
      "bucket": "<bucket>",
      "base_path": "<ruta-base>",
      "database_name": "db_aecorsoft_dev",
      "table_name": "aecorsoft_data",
      "athena_table_key": "aecorsoft_data"
    }
  },
  "athena": {
    "aecorsoft_data": {
      "enabled": true,
      "sql_path": "./src/sql/create_table_aecorsoft.sql",
      "merge_existing": true
    }
  }
}
```

`athena_table_key` relaciona la Step Function con la entrada correspondiente del
bloque `athena`. Terraform deriva el `s3_location` desde `bucket` y `base_path`.

Si la tabla no existe, el modulo Athena crea la base de datos Glue y la tabla. Si
ya existe y no hay cambios, Terraform no aplica cambios. Con `merge_existing =
true`, el modulo preserva columnas existentes y agrega nuevas columnas definidas
en el SQL.

## Componentes AWS creados

- 1 o mas Step Functions, segun `deploy.json`
- Base de datos y tabla Glue/Athena, si `athena.<key>.enabled = true`
