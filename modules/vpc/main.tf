resource "aws_vpc" "this" {
  cidr_block = var.vpc_cidr

  enable_dns_support   = true
  enable_dns_hostnames = true

  tags = {
    Name = "${var.environment}-vpc"
  }
}
resource "aws_vpc_ipv4_cidr_block_association" "secondary" {
  vpc_id     = aws_vpc.this.id
  cidr_block = var.secondary_cidr
}
resource "aws_subnet" "public"{
    for_each= var.public_subnets
    vpc_id=aws_vpc.this.id
    cidr=each.value.cidr
    az=each.value.az
    map_public_ip_on_launch = true
    tags={
        name=each.key
        type=public
    }
}
