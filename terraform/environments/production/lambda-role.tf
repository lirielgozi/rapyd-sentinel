# Create Lambda execution role separately to avoid circular dependency
# This role will be used by the Lambda and added to EKS aws-auth

resource "aws_iam_role" "lambda_deployer" {
  name = "${var.project_name}-eks-deployer-role"

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

  tags = local.common_tags
}

# Attach necessary policies for Lambda to work
resource "aws_iam_role_policy_attachment" "lambda_vpc_execution" {
  role       = aws_iam_role.lambda_deployer.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaVPCAccessExecutionRole"
}

# ECR read access for Lambda container images
resource "aws_iam_role_policy_attachment" "lambda_ecr_read" {
  role       = aws_iam_role.lambda_deployer.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
}

# Policy for EKS access
resource "aws_iam_role_policy" "lambda_eks_access" {
  name = "${var.project_name}-lambda-eks-access"
  role = aws_iam_role.lambda_deployer.id

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
      }
    ]
  })
}

# Output the role ARN for use in other modules
output "lambda_deployer_role_arn" {
  value = aws_iam_role.lambda_deployer.arn
  description = "ARN of the Lambda deployer role"
}