resource "aws_security_group" "worker_nodes" {

  name        = "${var.cluster_name}-worker-sg"
  description = "Shared worker node security group"

  vpc_id = var.vpc_id

  # OUTBOUND INTERNET/AWS API ACCESS
  egress {

    from_port   = 0
    to_port     = 0
    protocol    = "-1"

    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {

    Name = "${var.cluster_name}-worker-sg"

    # REQUIRED FOR KARPENTER DISCOVERY
    "karpenter.sh/discovery" = var.cluster_name
  }
}
resource "aws_security_group_rule" "worker_self" {

  type = "ingress"

  from_port = 0
  to_port   = 65535

  protocol = "-1"

  self = true

  security_group_id = aws_security_group.worker_nodes.id
}