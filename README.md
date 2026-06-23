# artifact1-aecorsoft

**Artefacto 1** — Integracion Aecorsoft con AWS Step Functions.

## Arquitectura

```
Orquestador (Artefacto 2)
    │
    ▼
Step Function Aecorsoft
    │
    ├── RunAecorsoftCLI
    │   └── aws-sdk:ssm:sendCommand → EC2 ejecuta CLI Aecorsoft
    │
    ├── WaitCommand / GetCommandInvocation
    │   └── espera fin del comando SSM
    │
    ├── ParseAecorsoftResult
    │   └── Lambda parser extrae estado, codproceso y ruta S3 desde logs
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

La funcion Lambda parser se gestiona durante el despliegue usando el modulo
`lambda` del mismo repositorio de templates.

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
    ├── sql/create_table_aecorsoft.sql
    └── lambda/aecorsoft_parser/main.py
```

## Despliegue

1. Crear repo `artifact1-aecorsoft` en GitHub
2. Subir el codigo
3. Configurar secrets en GitHub Actions:
   - `AWS_ACCESS_KEY_ID`
   - `AWS_SECRET_ACCESS_KEY`
   - `AWS_REGION`
   - `STEP_FUNCTION_ROLE_ARN`
   - `LAMBDA_ROLE_ARN`
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
      "bucket": "artifact1-aecorsoft-landing-850995559699-us-east-1",
      "base_path": "AECORSOFT/aecorsoft_data",
      "commands": [
        "Set-Location 'C:\\Program Files\\AecorSoft\\AecorSoft Data Integrator'",
        ".\\adimgr.exe run -t XXXXXX -u TU_USUARIO:TU_PASSWORD"
      ],
      "database_name": "db_aecorsoft_dev",
      "table_name": "aecorsoft_data",
      "athena_table_key": "aecorsoft_data",
      "parser_lambda_key": "aecorsoft_parser"
    }
  },
  "athena": {
    "aecorsoft_data": {
      "enabled": true,
      "sql_path": "./src/sql/create_table_aecorsoft.sql",
      "merge_existing": false
    }
  },
  "lambda": {
    "aecorsoft_parser": {
      "enabled": true,
      "function_name": "lambda-aecorsoft-parser-dev",
      "source_path": "./src/lambda/aecorsoft_parser",
      "handler": "main.handler",
      "runtime": "python3.11"
    }
  }
}
```

`athena_table_key` relaciona la Step Function con la entrada correspondiente del
bloque `athena`. El `LOCATION` de la tabla se define dentro del archivo SQL,
igual que en el repo `artifact3-demo-consumer`.

`parser_lambda_key` relaciona la Step Function con la Lambda parser definida en
el bloque `lambda`. Esta Lambda recibe el output de `ssm:getCommandInvocation`,
detecta si Aecorsoft termino en exito real, extrae el `codproceso` desde la ruta
S3 reportada por Aecorsoft y retorna la particion que Athena debe registrar.

La Lambda considera exitosa la ejecucion de Aecorsoft solo si el comando SSM
termina en `Success`, el log contiene `Task completed.`, contiene `Upload: done.`
y existe una ruta S3 con `codproceso=`. Luego la Step Function valida una sola
vez que existan objetos en esa particion S3; si no existen, falla con
`S3OutputNotFound`.

Si la tabla no existe, el modulo Athena crea la base de datos Glue y la tabla. Si
ya existe en el estado de Terraform y no hay cambios, Terraform no aplica
cambios.

## Componentes AWS creados

- 1 o mas Step Functions, segun `deploy.json`
- Base de datos y tabla Glue/Athena, si `athena.<key>.enabled = true`
- Funcion Lambda parser, si `lambda.<key>.enabled = true`
