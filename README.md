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

La funcion Lambda parser es compartida y debe existir previamente en AWS. Este
artefacto solo referencia su ARN desde `deploy.json`.

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
├── .github/workflows/terraform-qas.yml
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
4. Configurar secrets en GitHub Environment `qas`:
   - `AWS_REGION`
   - `STEP_FUNCTION_ROLE_ARN`
5. Editar `deploy.json` con valores reales
6. Ir a Actions → `Terraform qas - Artifact 1 Aecorsoft` → Run workflow

El workflow actual despliega solo `qas` y usa state separado en
`state/artifact1-aecorsoft/terraform.tfstate`. Los ambientes `dev` y `prd`
quedan preparados para una fase posterior mediante cuentas/buckets de state
separados.

## Manifest `deploy.json`

El manifiesto separa la orquestacion (`step_functions`) de la creacion de tablas
(`athena`), siguiendo el patron del repo `artifact3-demo-consumer`.

```json
{
  "step_functions": {
    "aecorsoft_integration": {
      "enabled": true,
      "enabled_environments": ["qas"],
      "name": "sf-aecorsoft-integration",
      "definition_path": "./src/state_machine/aecorsoft_sfn.json",
      "commands": [
        "Set-Location 'C:\\Program Files\\AecorSoft\\AecorSoft Data Integrator'",
        ".\\adimgr.exe run -t XXXXXX -u TU_USUARIO:TU_PASSWORD"
      ],
      "database_name": "db_aecorsoft",
      "table_name": "aecorsoft_data",
      "athena_table_key": "aecorsoft_data",
      "environment_values": {
        "qas": {
          "instance_id": "i-0972a8b5c48424e6e",
          "s3_location": "s3://ue1stgtestas3dtl001-landing/UE1STGTESTS3LOG001/SAP/CSKT/prueba/",
          "athena_results_bucket": "artifact1-aecorsoft-athena-850995559699-us-east-1",
          "parser_lambda_arn": "arn:aws:lambda:us-east-1:850995559699:function:lambda-aecorsoft-parser-dev"
        }
      }
    }
  },
  "athena": {
    "aecorsoft_data": {
      "enabled": true,
      "enabled_environments": ["qas"],
      "sql_path": "./src/sql/create_table_aecorsoft.sql",
      "database_name": "db_aecorsoft",
      "table_name": "aecorsoft_data",
      "merge_existing": false
    }
  }
}
```

`athena_table_key` relaciona la Step Function con la entrada correspondiente del
bloque `athena`. Como cada ambiente vive en una cuenta AWS distinta, Terraform no
agrega sufijos de ambiente a los nombres fisicos: usa `sf-aecorsoft-integration`
y `db_aecorsoft`.

`environment_values.qas.s3_location` define la ruta S3 fisica para QAS. Terraform
la usa como `s3_location` de Athena y tambien separa bucket/prefix para la Step
Function.

`environment_values.qas.parser_lambda_arn` referencia la Lambda parser compartida.
Esta Lambda recibe el output de `ssm:getCommandInvocation`, detecta si Aecorsoft
termino en exito real, extrae el `codproceso` desde la ruta S3 reportada por
Aecorsoft y retorna la particion que Athena debe registrar.

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
