provider "aws" {
  region = "ap-northeast-1"
  default_tags {
    tags = {
      env = var.env
      project = var.project
    }
  }  
}

terraform {
  required_version = ">= 0.11.0"
  backend "s3" {
    bucket = "martin-terraform-tfstate-bucket"
    region = "ap-northeast-1"
    key = "dev/garbage_day_notification.terraform.tfstate"
    encrypt = true
  }
}

resource "aws_s3_bucket" "terraform_state" {
  bucket = "martin-terraform-tfstate-bucket"
  force_destroy = true
}
resource "aws_s3_bucket_versioning" "terraform_state_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
}