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

module "rds" {
  source            = "../../modules/rds"
  project           = var.project
  env               = var.env
  db_name           = var.db_name
  db_username       = var.db_username
  db_password       = var.db_password
  subnet_ids        = module.networking.private_subnet_id
  security_group_id = module.security.rds_security_group_id
}
