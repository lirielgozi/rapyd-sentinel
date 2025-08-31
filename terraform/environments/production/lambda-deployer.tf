# Lambda deployer for EKS clusters
module "lambda_deployer" {
  source = "../../modules/lambda-deployer"

  function_name = "${var.project_name}-eks-deployer"
  
  # Use the pre-created role to avoid circular dependency
  use_existing_role = true
  existing_role_arn = aws_iam_role.lambda_deployer.arn
  
  # Run Lambda in backend VPC so it can access private EKS endpoint
  vpc_id     = module.vpc_backend.vpc_id
  subnet_ids = module.vpc_backend.private_subnet_ids
  
  # Backend cluster configuration
  backend_cluster_name     = module.eks_backend.cluster_name
  backend_cluster_endpoint = module.eks_backend.cluster_endpoint
  backend_cluster_ca       = module.eks_backend.cluster_certificate_authority_data
  backend_ecr_url         = aws_ecr_repository.backend.repository_url
  
  # Gateway cluster configuration  
  gateway_cluster_name     = module.eks_gateway.cluster_name
  gateway_cluster_endpoint = module.eks_gateway.cluster_endpoint
  gateway_cluster_ca       = module.eks_gateway.cluster_certificate_authority_data
  gateway_ecr_url         = aws_ecr_repository.gateway.repository_url
  
  region = var.region
  tags   = local.common_tags
  
  depends_on = [
    module.eks_backend,
    module.eks_gateway
  ]
}

# Output for GitHub Actions to use
output "lambda_deployer_function_name" {
  description = "Lambda function name for EKS deployments"
  value       = module.lambda_deployer.function_name
}