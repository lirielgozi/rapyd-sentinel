# IAM role for Lambda (only create if not using existing role)
resource "aws_iam_role" "lambda" {
  count = var.use_existing_role ? 0 : 1
  
  name = "${var.function_name}-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = var.tags
}

# Local variable for the role ARN to use
locals {
  lambda_role_arn = var.use_existing_role ? var.existing_role_arn : aws_iam_role.lambda[0].arn
  lambda_role_id  = var.use_existing_role ? split("/", var.existing_role_arn)[1] : aws_iam_role.lambda[0].id
}

# Policy for EKS access (only create if we created the role)
resource "aws_iam_role_policy" "lambda_eks" {
  count = var.use_existing_role ? 0 : 1
  
  name = "${var.function_name}-eks-policy"
  role = aws_iam_role.lambda[0].id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:AccessKubernetesApi"
        ]
        Resource = "*"
      },
      {
        Effect = "Allow"
        Action = [
          "sts:AssumeRole"
        ]
        Resource = "*"
      }
    ]
  })
}

# Attach VPC execution policy (skip if using existing role)
resource "aws_iam_role_policy_attachment" "lambda_vpc" {
  count      = var.use_existing_role ? 0 : 1
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# Attach ECR read policy (skip if using existing role)
resource "aws_iam_role_policy_attachment" "lambda_ecr" {
  count      = var.use_existing_role ? 0 : 1
  role       = aws_iam_role.lambda[0].name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}