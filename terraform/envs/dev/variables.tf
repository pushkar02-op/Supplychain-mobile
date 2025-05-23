variable "aws_region" {
  default = "ap-south-1"
}

variable "aws_profile" {
  default = "terraform" # as configured via aws configure --profile terraform
}

variable "vpc_cidr" {
  default = "10.0.0.0/16"
}

variable "db_name" {
  default = "fruitvendor"
}

variable "db_username" {
  default = "admin"
}

variable "db_password" {
  description = "RDS password"
  sensitive   = true
}

variable "my_ip_cidr" {
  description = "Your current IP address in CIDR notation to allow SSH access"
  type        = string
}

variable "key_name" {
  description = "SSH key pair name"
  type        = string
}
