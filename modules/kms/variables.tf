variable "description" {

  description = "KMS key description"

  type = string
}

variable "alias" {

  description = "KMS alias name"

  type = string
}

variable "tags" {

  description = "Common tags"

  type = map(string)

  default = {}
}