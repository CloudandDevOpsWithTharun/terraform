resource "aws_iam_role" "this" {

  name = var.role_name

  assume_role_policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {

        Effect = "Allow"

        Principal = {
          Service = "pods.eks.amazonaws.com"
        }

        Action = [
          "sts:AssumeRole",
          "sts:TagSession"
        ]
      }
    ]
  })
}

resource "aws_iam_policy" "this" {

  name = "${var.role_name}-policy"

  policy = jsonencode({

    Version = "2012-10-17"

    Statement = [

      {
        Effect = "Allow"

        Action = [
          "secretsmanager:GetSecretValue"
        ]

        Resource = [
          var.secret_arn
        ]
      },

      {
        Effect = "Allow"

        Action = [
          "kms:Decrypt"
        ]

        Resource = [
          var.kms_key_arn
        ]
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "this" {

  role = aws_iam_role.this.name

  policy_arn = aws_iam_policy.this.arn
}