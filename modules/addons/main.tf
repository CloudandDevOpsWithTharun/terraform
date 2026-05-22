# EKS Pod Identity Agent
# Enables pods to securely obtain IAM credentials
resource "aws_eks_addon" "pod_identity" {

  cluster_name = var.cluster_name
  addon_name   = "eks-pod-identity-agent"

  resolve_conflicts_on_update = "OVERWRITE"
}