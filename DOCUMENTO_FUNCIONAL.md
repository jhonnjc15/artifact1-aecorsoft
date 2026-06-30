# Documento Funcional - Artifact 1 Aecorsoft

## Objetivo

`artifact1-aecorsoft` implementa la integracion funcional con Aecorsoft usando AWS Step Functions. El artefacto ejecuta el cliente Aecorsoft en una instancia EC2 mediante SSM, interpreta el resultado con una Lambda parser existente, valida que la salida llegue a S3 y registra la particion correspondiente en Athena.

## Alcance

Este repo gestiona:

| Componente | Responsabilidad |
|---|---|
| Step Function | Orquestar la ejecucion Aecorsoft y las validaciones posteriores |
| Glue/Athena database/table | Registrar la tabla consultable por Athena |
| State Terraform | Mantener estado remoto por repo en S3 |
| Workflow QAS | Ejecutar plan/apply manual desde GitHub Actions |

Este repo no gestiona:

| Componente | Motivo |
|---|---|
| Lambda parser | Se referencia una Lambda compartida existente por ARN |
| EC2 Aecorsoft | Debe existir y estar administrada fuera de este artefacto |
| Credenciales Aecorsoft finales | Aun deben reemplazarse los placeholders del comando |

## Arquitectura Funcional

```text
Orquestador externo
-> Step Function sf-aecorsoft-integration
-> SSM sendCommand sobre EC2
-> WaitCommand
-> SSM getCommandInvocation
-> Lambda parser compartida
-> Validacion de objetos en S3
-> Athena ADD PARTITION
-> Success o Failure
```

La Step Function es el punto de orquestacion. La tabla Glue/Athena se crea durante el despliegue Terraform. En runtime, la Step Function solo agrega particiones.

## Estructura Del Repo

```text
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

## Manifest deploy.json

`deploy.json` es la declaracion funcional del artefacto. Actualmente tiene tres bloques principales:

| Bloque | Funcion |
|---|---|
| `databases` | Declara Glue Databases como `create` o `existing` |
| `step_functions` | Define orquestadores Step Functions |
| `athena` | Define tablas Glue/Athena |

### Databases

La entrada `databases.aecorsoft` define `db_aecorsoft` y su modo de gestion. Con
`mode = "create"`, Terraform crea la database una sola vez desde el root del
artefacto. Las tablas Athena la referencian mediante `database_key`.

### Step Function

La entrada `step_functions.aecorsoft_integration` define:

| Campo | Funcion |
|---|---|
| `enabled` | Activa o desactiva el componente |
| `enabled_environments` | Ambientes donde aplica el componente |
| `name` | Nombre fisico de la Step Function |
| `definition_path` | Ruta al ASL JSON |
| `commands` | Comandos ejecutados por SSM en la EC2 |
| `wait_seconds` | Espera entre SSM sendCommand y getCommandInvocation |
| `athena_table_key` | Relacion con una entrada del bloque `athena`; desde ahi se deriva database/table |
| `environment_values` | Valores especificos por ambiente |

### Valores Por Ambiente

Para `qas`, el manifest define:

| Campo | Funcion |
|---|---|
| `instance_id` | EC2 donde corre Aecorsoft |
| `s3_location` | Ruta fisica de salida en S3 |
| `athena_results_bucket` | Bucket donde Athena escribe resultados de queries |
| `parser_lambda_arn` | ARN de la Lambda parser existente |

El `s3_location` se usa para dos cosas:

| Uso | Descripcion |
|---|---|
| Step Function | Deriva `bucket` y `base_path` para validar objetos |
| Athena | Define la ubicacion fisica de la tabla |

## Lambda Parser Externa

La Lambda parser no se crea desde este repo. Se referencia mediante:

```text
arn:aws:lambda:us-east-1:850995559699:function:lambda-aecorsoft-parser-dev
```

La Lambda recibe el resultado de `ssm:getCommandInvocation` y debe devolver la informacion necesaria para que la Step Function valide la salida y registre la particion.

Condiciones funcionales esperadas:

| Condicion | Resultado |
|---|---|
| SSM termina en `Success` | La ejecucion tecnica termino correctamente |
| Log contiene `Task completed.` | Aecorsoft reporto finalizacion funcional |
| Log contiene `Upload: done.` | Aecorsoft reporto carga a S3 |
| Log contiene ruta con `codproceso=` | Se puede derivar la particion Athena |

Punto pendiente: confirmar si el ARN con nombre `dev` es el correcto para el ambiente `qas`.

## Tabla Athena

La tabla se define en `deploy.json` bajo `athena.aecorsoft_data` y el SQL base vive en:

```text
src/sql/create_table_aecorsoft.sql
```

El modulo Athena se consume desde:

```text
git::https://github.com/jhonnjc15/artifact3-terraform-templates.git//modules/athena?ref=main
```

El nombre fisico actual es:

| Recurso | Nombre |
|---|---|
| Database | `db_aecorsoft` |
| Table | `aecorsoft_data` |

No se agregan sufijos como `-qas` porque el aislamiento de ambiente se realiza por cuenta AWS y bucket de state.

## Terraform

### Backend

`backend.tf` declara un backend S3 parcial:

```hcl
terraform {
  backend "s3" {
    encrypt = true
  }
}
```

El workflow completa los valores en `terraform init`:

```text
bucket = secrets.TF_STATE_BUCKET
region = secrets.AWS_REGION
key    = state/<repo>/terraform.tfstate
```

Para este repo, la key esperada es:

```text
state/artifact1-aecorsoft/terraform.tfstate
```

### Variables

El workflow genera `qas.auto.tfvars` con:

| Variable | Fuente |
|---|---|
| `aws_region` | `secrets.AWS_REGION` |
| `step_function_role_arn` | `secrets.STEP_FUNCTION_ROLE_ARN` |

`terraform plan` agrega:

| Variable | Valor |
|---|---|
| `environment` | `qas` |
| `github_repository` | `${{ github.repository }}` |

## Workflow QAS

Archivo:

```text
.github/workflows/terraform-qas.yml
```

Ejecucion:

```text
workflow_dispatch
```

Input:

| Input | Funcion |
|---|---|
| `apply` | Si es `false`, solo genera plan. Si es `true`, ejecuta apply |

Secrets requeridos en el GitHub Environment `qas`:

| Secret | Uso |
|---|---|
| `AWS_ACCESS_KEY_ID` | Credencial AWS temporal o tecnica |
| `AWS_SECRET_ACCESS_KEY` | Credencial AWS temporal o tecnica |
| `AWS_REGION` | Region AWS |
| `TF_STATE_BUCKET` | Bucket remoto de Terraform state |
| `STEP_FUNCTION_ROLE_ARN` | Role usado por Step Functions |

## Tags

Tags comunes actuales:

```hcl
environment = var.environment
managed_by  = "terraform"
project     = "aecorsoft"
```

Punto recomendado: agregar `github_repo = var.github_repository` para homologar trazabilidad con los consumers del Artefacto 3.

## Permisos AWS Requeridos

La identidad que ejecuta Terraform necesita permisos para gestionar:

| Servicio | Acciones funcionales |
|---|---|
| Step Functions | Crear/actualizar state machines |
| Glue Data Catalog | Crear/actualizar database y table |
| IAM | Pasar o referenciar roles segun la politica aplicada |
| S3 backend | Leer/escribir state remoto |

El role de Step Functions necesita permisos runtime para:

| Servicio | Uso |
|---|---|
| SSM | `sendCommand` y `getCommandInvocation` |
| Lambda | Invocar la Lambda parser |
| S3 | Validar objetos de salida |
| Athena | Ejecutar `ADD PARTITION` |

## Riesgos Y Pendientes

| Prioridad | Punto |
|---|---|
| Alta | Reemplazar `XXXXXX`, `TU_USUARIO` y `TU_PASSWORD` en `commands` |
| Alta | Confirmar si `lambda-aecorsoft-parser-dev` es valida para QAS |
| Alta | Resolver cualquier explicit deny IAM antes de `apply` real |
| Alta | Revisar state si antes se uso otra key o si la Lambda estaba en state |
| Media | Versionar el modulo Athena con tag en vez de `ref=main` |
| Media | Agregar validaciones Terraform para campos obligatorios |
| Media | Agregar tag `github_repo` |
| Media | Migrar de access keys a OIDC |

## Operacion Recomendada

1. Actualizar `deploy.json` con valores reales.
2. Confirmar que la Lambda parser existe y puede ser invocada por Step Functions.
3. Confirmar que la EC2 tiene SSM Agent operativo y permisos adecuados.
4. Ejecutar workflow con `apply = false`.
5. Revisar el plan Terraform.
6. Ejecutar workflow con `apply = true` solo despues de aprobacion.
7. Probar ejecucion funcional de la Step Function.
