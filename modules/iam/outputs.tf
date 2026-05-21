output "eks_cluster_role_arn" {
  value = aws_iam_role.eks_cluster.arn
}

output "node_role_arn" {
  value = aws_iam_role.node_group.arn
}
output "eks_cluster_policy_attachment" {
  value = aws_iam_role_policy_attachment.eks_cluster.id
}