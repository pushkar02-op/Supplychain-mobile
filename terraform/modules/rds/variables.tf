variable "project" {}
variable "env" {}

variable "db_name" {}
variable "db_username" {}
variable "db_password" {}

variable "subnet_ids" {
  type = list(string)
}

variable "security_group_id" {
  description = "Security group that allows FastAPI app to connect"
}
