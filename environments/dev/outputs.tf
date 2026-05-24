output "vpc_id" {
  value = module.vpc.vpc_id
}
output "cluster_name" {
  value = module.eks.cluster_name
}
output "region" {
  value = var.aws_region
}
output "public_subnets_ids" {
  value = module.vpc.public_subnet_ids
}
output "private_subnets_ids" {
  value = module.vpc.private_subnet_ids
}
output "pod_subnets_ids" {
  value = module.vpc.pod_subnet_ids
}

output "cluster_security_group_id" {
  value = module.eks.cluster_sg

}