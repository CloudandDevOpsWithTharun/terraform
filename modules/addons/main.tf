# EKS Pod Identity Agent
# Enables pods to securely obtain IAM credentials
resource "aws_eks_addon" "pod_identity" {

  cluster_name = var.cluster_name
  addon_name   = "eks-pod-identity-agent"

  resolve_conflicts_on_update = "OVERWRITE"
}
# addons.tf

# ──────────────────────────────────────────────
# 1. VPC CNI — must apply BEFORE nodegroup registers
#    so nodes pick up custom networking from boot
# ──────────────────────────────────────────────
resource "aws_eks_addon" "vpc_cni" {
  cluster_name                = var.cluster_name
  addon_name                  = "vpc-cni"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"

  configuration_values = jsonencode({
    env = {
      ENABLE_PREFIX_DELEGATION           = "true"
      WARM_PREFIX_TARGET                 = "1"
      AWS_VPC_K8S_CNI_CUSTOM_NETWORK_CFG = "true"
      ENI_CONFIG_LABEL_DEF               = "topology.kubernetes.io/zone"
      ENABLE_POD_ENI                     = "false" # t3.medium = no trunk ENI support
                                                   # flip to true only after moving to m5+
    }
  })


}

# ──────────────────────────────────────────────
# 3. CoreDNS — needs nodes to actually schedule
#    so depends on bootstrap nodegroup
# ──────────────────────────────────────────────
resource "aws_eks_addon" "coredns" {
  cluster_name                = var.cluster_name
  addon_name                  = "coredns"
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_eks_pod_identity_association" "vpc_cni" {
  cluster_name    = var.cluster_name
  namespace       = "kube-system"
  service_account = "aws-node"          # VPC CNI's service account name — do not change
  role_arn        = var.vpc_cni_role_arn

  depends_on = [
    aws_eks_addon.pod_identity           # agent must exist before association
  ]
}