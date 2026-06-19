terraform {
  backend "s3" {
    bucket  = "artifact1-aecorsoft-tfstate-850995559699-us-east-1"
    region  = "us-east-1"
    encrypt = true
  }
}
