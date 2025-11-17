terraform {
  backend "gcs" {
    bucket = "hello-world"
    prefix = "terraform.tfstate"
  }
}