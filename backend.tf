terraform {
  backend "s3" {
    bucket  = "artifact3-terraform-state"
    region  = "us-east-1"
    encrypt = true
  }
}
