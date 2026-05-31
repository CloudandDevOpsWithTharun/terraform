variable "name" {
  type = string
}

variable "vpc_id" {
  type = string
}

variable "private_subnet_ids" {
  type = list(string)
}


variable "kms_key_arn" {
  type = string
}

variable "instance_class" {
  type = string
  default = "db.t3.medium"
}

variable "master_username" {
  type = string
  default = "postgres"
}

variable "tags" {
  type    = map(string)
  default = {}
}
variable "username" {

  type = string
}

variable "password" {

  type      = string
  sensitive = true
}

variable "db_name" {

  type = string
}