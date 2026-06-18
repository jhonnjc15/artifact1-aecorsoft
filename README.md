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

## Componentes AWS creados

- 1 Step Function (`sf-aecorsoft-integration-dev`)
