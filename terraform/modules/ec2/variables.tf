variable "public_subnet_id" {
  description = "Public subnet ID"
  type        = string
}

variable "ec2_sg_id" {
  description = "EC2 security group ID"
  type        = string
}

variable "key_name" {
  description = "Key pair name for SSH"
  type        = string
}
