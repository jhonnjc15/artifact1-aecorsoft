variable "aws_region" {
  description = "Region AWS donde se desplegara la solucion."
  type        = string
  default     = "us-east-1"
}

variable "environment" {
  description = "Ambiente objetivo del despliegue. Actualmente se usa qas; dev/prd quedan preparados para una fase posterior."
  type        = string
  default     = "qas"

  validation {
    condition     = contains(["dev", "qas", "prd"], var.environment)
    error_message = "environment debe ser uno de: dev, qas, prd."
  }
}

variable "step_function_role_arn" {
  description = "ARN del IAM Role existente para AWS Step Functions."
  type        = string
}

variable "artifact_bucket" {
  description = "Bucket S3 donde se subira el codigo empaquetado de Lambda."
  type        = string
  default     = "sf-datalake-850995559699-artifacts"
}

variable "lambda_role_arn" {
  description = "ARN del IAM Role existente para AWS Lambda."
  type        = string
}

variable "github_repository" {
  description = "Repositorio GitHub que ejecuta el deploy (formato: owner/repo)."
  type        = string
}
