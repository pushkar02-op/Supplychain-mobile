terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "local" {
    path = "./terraform.tfstate"
  }
}

provider "aws" {
  region  = var.aws_region
  profile = var.aws_profile
}

module "networking" {
  source     = "../../modules/networking"
  vpc_cidr   = var.vpc_cidr
  aws_region = var.aws_region
}


module "security" {
  source     = "../../modules/security"
  vpc_id     = module.networking.vpc_id
  my_ip_cidr = var.my_ip_cidr
}


module "ec2" {
  source           = "../../modules/ec2"
  public_subnet_id = module.networking.public_subnet_id[0]
  ec2_sg_id        = module.security.ec2_security_group_id
  key_name         = var.key_name
}


