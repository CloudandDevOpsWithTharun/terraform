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
    cidr_block=each.value.cidr
    availability_zone=each.value.az
    map_public_ip_on_launch = true
    tags={
        Name=each.key
        Type="public"
        "kubernetes.io/role/elb" = "1"
          

  # Marks subnet as usable by this EKS cluster
  "kubernetes.io/cluster/prime360novac-1" = "shared"
    }
}
resource "aws_internet_gateway" "this" {

  vpc_id = aws_vpc.this.id

  tags = {
    Name = "${var.environment}-igw"
  }
}
resource "aws_route_table" "public" {

  vpc_id = aws_vpc.this.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.this.id
  }

  tags = {
    Name = "${var.environment}-public-rt"
  }
}

resource "aws_route_table_association" "public" {

  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

resource "aws_subnet" "private"{
  for_each=var.private_subnets
  vpc_id=aws_vpc.this.id
  cidr_block=each.value.cidr
  availability_zone=each.value.az
  tags={
    Name=each.key
    Type="private"
    "kubernetes.io/role/internal-elb" = "1"
      # Allows Karpenter to discover node-capable subnets
  "karpenter.sh/discovery" = "prime360novac-1"

  # Marks subnet as usable by this EKS cluster
  "kubernetes.io/cluster/prime360novac-1" = "shared"
  }


}
resource "aws_route_table" "private" {

  vpc_id = aws_vpc.this.id
  route {
  cidr_block     = "0.0.0.0/0"
  nat_gateway_id = aws_nat_gateway.this.id
}
  tags = {
    Name = "${var.environment}-private-rt"
  }
}

resource "aws_route_table_association" "private" {

  for_each = aws_subnet.private

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}
resource "aws_eip" "nat" {
  domain = "vpc"

  tags = {
    Name = "${var.environment}-nat-eip"
  }
}
resource "aws_nat_gateway" "this" {
  allocation_id = aws_eip.nat.id

  subnet_id = aws_subnet.public["public-a"].id

  tags = {
    Name = "${var.environment}-nat"
  }

  depends_on = [aws_internet_gateway.this]
}

resource "aws_subnet" "pod" {
  for_each = var.pod_subnets

  vpc_id            = aws_vpc.this.id
  cidr_block        = each.value.cidr
  availability_zone = each.value.az

  tags = {
    Name = each.key
    Type = "pod"
  }
}
resource "aws_route_table_association" "pod" {
  for_each = aws_subnet.pod

  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}