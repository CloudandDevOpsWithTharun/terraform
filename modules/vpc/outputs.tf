output "vpc_id" {
  value = aws_vpc.this.id
}
output "private_subnet_ids" {
  value = values(aws_subnet.private)[*].id
}
output "public_subnet_ids" {
  value = values(aws_subnet.public)[*].id
}

output "pod_subnet_ids" {
  value = values(aws_subnet.pod)[*].id
}
