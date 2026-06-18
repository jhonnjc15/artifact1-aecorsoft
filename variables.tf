variable "aws_region" {
  description = "Region AWS donde se desplegara la solucion."
  type        = string
  default     = "us-east-1"
}

variable "step_function_role_arn" {
  description = "ARN del IAM Role existente para AWS Step Functions."
  type        = string
}

variable "github_repository" {
  description = "Repositorio GitHub que ejecuta el deploy (formato: owner/repo)."
  type        = string
}
