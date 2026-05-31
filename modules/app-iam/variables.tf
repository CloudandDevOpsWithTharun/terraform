variable "role_name" {

  description = "IAM role name for application"

  type = string
}

variable "secret_arn" {

  description = "Secrets Manager secret ARN"

  type = string
}

variable "kms_key_arn" {

  description = "KMS key ARN"

  type = string
}