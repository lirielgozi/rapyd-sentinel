# Lambda function for deploying to EKS clusters
resource "aws_lambda_function" "deployer" {
  function_name = var.function_name
  role          = local.lambda_role_arn
  timeout       = 300
  memory_size   = 1024
  
  # Use container image from ECR
  package_type = "Image"
  image_uri    = "${aws_ecr_repository.lambda.repository_url}:latest"

  vpc_config {
    subnet_ids         = var.subnet_ids
    security_group_ids = [aws_security_group.lambda.id]
  }

  environment {
    variables = {
      BACKEND_CLUSTER_NAME     = var.backend_cluster_name
      GATEWAY_CLUSTER_NAME     = var.gateway_cluster_name
      BACKEND_CLUSTER_ENDPOINT = var.backend_cluster_endpoint
      GATEWAY_CLUSTER_ENDPOINT = var.gateway_cluster_endpoint
      BACKEND_CLUSTER_CA       = var.backend_cluster_ca
      GATEWAY_CLUSTER_CA       = var.gateway_cluster_ca
      BACKEND_ECR_URL         = var.backend_ecr_url
      GATEWAY_ECR_URL         = var.gateway_ecr_url
      REGION                  = var.region
    }
  }

  # No layers needed since we're using boto3/requests directly

  tags = var.tags

  depends_on = [
    aws_iam_role_policy_attachment.lambda_vpc,
    aws_iam_role_policy.lambda_eks,
    null_resource.docker_build
  ]
}

# No kubectl layer needed since we're using boto3/requests API directly