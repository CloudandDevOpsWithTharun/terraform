variable "environment" {
  type = string
}

variable "vpc_cidr" {
  type = string
}

variable "secondary_cidr" {
  type = string
}

variable "availability_zones" {
  type = list(string)
}

variable "public_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "private_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
}

variable "pod_subnets" {
  type = map(object({
    cidr = string
    az   = string
  }))
}