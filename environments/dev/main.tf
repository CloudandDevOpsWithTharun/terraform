module "vpc" {
  source = "../../modules/vpc"

  environment      = "dev"
  vpc_cidr         = "10.0.0.0/16"
  secondary_cidr   = "100.64.0.0/16"

  availability_zones = [
    "ap-southeast-1a",
    "ap-southeast-1b",
    "ap-southeast-1c"
  ]
}