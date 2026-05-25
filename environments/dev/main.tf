module "vpc" {
  source = "../../modules/vpc"

  environment    = "dev"
  vpc_cidr       = "10.0.0.0/16"
  secondary_cidr = "100.64.0.0/16"

  availability_zones = [
    "ap-southeast-1a",
    "ap-southeast-1b",
    "ap-southeast-1c"
  ]
  public_subnets = {
    public-a = {
      cidr = "10.0.1.0/24"
      az   = "ap-southeast-1a"
    }

    public-b = {
      cidr = "10.0.2.0/24"
      az   = "ap-southeast-1b"
    }

    public-c = {
      cidr = "10.0.3.0/24"
      az   = "ap-southeast-1c"
    }
  }
  private_subnets = {
    private-a = {
      cidr = "10.0.11.0/24"
      az   = "ap-southeast-1a"
    }

    private-b = {
      cidr = "10.0.12.0/24"
      az   = "ap-southeast-1b"
    }

    private-c = {
      cidr = "10.0.13.0/24"
      az   = "ap-southeast-1c"
    }
  }

  pod_subnets = {
    pod-a = {
      cidr = "100.64.1.0/24"
      az   = "ap-southeast-1a"
    }

    pod-b = {
      cidr = "100.64.2.0/24"
      az   = "ap-southeast-1b"
    }

    pod-c = {
      cidr = "100.64.3.0/24"
      az   = "ap-southeast-1c"
    }
  }
}

module "iam" {
  source = "../../modules/iam"

  cluster_name = "prime360novac-1"
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = "prime360novac-1"
  cluster_version = "1.33"

  vpc_id = module.vpc.vpc_id

  private_subnet_ids = module.vpc.private_subnet_ids

  cluster_role_arn = module.iam.eks_cluster_role_arn

  node_role_arn = module.iam.node_role_arn

  depends_on = [module.iam]
}

module "addons" {
  source           = "../../modules/addons"
  vpc_cni_role_arn = module.iam.vpc_cni_role_arn
  cluster_name     = "prime360novac-1"
  depends_on       = [module.eks, module.iam]
}