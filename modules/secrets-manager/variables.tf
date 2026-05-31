variable "secret_name" {

  description = "Secrets Manager secret name"

  type = string
}

variable "kms_key_arn" {

  description = "KMS key ARN used for secret encryption"

  type = string
}

variable "username" {

  description = "Database username"

  type = string
}

variable "db_name" {

  description = "Database name"

  type = string
}

variable "tags" {

  description = "Common tags"

  type = map(string)

  default = {}
}