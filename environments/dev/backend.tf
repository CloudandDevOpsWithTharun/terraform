terraform {

  backend "s3" {

    bucket = "prime360novac-terraform-state-783764580882-ap-southeast-1-an"

    key = "dev/terraform.tfstate"

    region = "ap-southeast-1"

    encrypt = true

    use_lockfile = true
  }
}