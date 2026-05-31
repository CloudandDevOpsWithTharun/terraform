# ──────────────────────────────────────────────
# EFS File System
# Shared persistent storage for Kubernetes pods
# ──────────────────────────────────────────────
resource "aws_efs_file_system" "this" {

  creation_token = "${var.cluster_name}-efs"

  performance_mode = "generalPurpose"

  throughput_mode = "elastic"

  encrypted = true

  kms_key_id = var.kms_key_id

  tags = {
    Name = "${var.cluster_name}-efs"
  }
}

# ──────────────────────────────────────────────
# Security Group for EFS
# Allows NFS traffic from worker nodes
# ──────────────────────────────────────────────
resource "aws_security_group" "efs" {

  name        = "${var.cluster_name}-efs-sg"

  description = "EFS security group"

  vpc_id = var.vpc_id

  ingress {

    description = "NFS from worker nodes"

    from_port = 2049
    to_port   = 2049

    protocol = "tcp"

    security_groups = [
      var.node_security_group_id
    ]
  }

  egress {

    from_port = 0
    to_port   = 0

    protocol = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "${var.cluster_name}-efs-sg"
  }
}

# ──────────────────────────────────────────────
# Mount Targets
# One per private subnet/AZ
# ──────────────────────────────────────────────
resource "aws_efs_mount_target" "this" {

  for_each = toset(var.private_subnet_ids)

  file_system_id = aws_efs_file_system.this.id

  subnet_id = each.value

  security_groups = [
    aws_security_group.efs.id
  ]
}

# ──────────────────────────────────────────────
# EFS Access Point
# Recommended for Kubernetes dynamic provisioning
# ──────────────────────────────────────────────
resource "aws_efs_access_point" "this" {

  file_system_id = aws_efs_file_system.this.id

  root_directory {

    path = "/k8s"

    creation_info {

      owner_gid   = 1000
      owner_uid   = 1000

      permissions = "755"
    }
  }

  tags = {
    Name = "${var.cluster_name}-efs-ap"
  }
}