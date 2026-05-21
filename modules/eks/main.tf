resource "aws_eks_cluster" "this" {
  name = var.cluster_name

  version = var.cluster_version

  role_arn = var.cluster_role_arn

  vpc_config {
    subnet_ids = var.private_subnet_ids

    endpoint_private_access = true
    endpoint_public_access  = true
  }

}

# Bootstrap node group required for initial cluster components
# Karpenter itself cannot start without initial compute capacity
resource "aws_eks_node_group" "bootstrap" {

  cluster_name    = aws_eks_cluster.this.name
  node_group_name = "${var.cluster_name}-bootstrap"

  node_role_arn = var.node_role_arn

  subnet_ids = var.private_subnet_ids

  ami_type       = "AL2023_x86_64_STANDARD"
  capacity_type  = "ON_DEMAND"
  instance_types = ["t3.medium"]

  scaling_config {
    desired_size = 2
    min_size     = 2
    max_size     = 3
  }

  update_config {
    max_unavailable = 1
  }

  depends_on = [
    aws_eks_cluster.this
  ]

  tags = {
    Name = "${var.cluster_name}-bootstrap"
  }
}
