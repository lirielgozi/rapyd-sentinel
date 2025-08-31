# Kubernetes providers for both EKS clusters

# Provider for Backend cluster
provider "kubernetes" {
  alias = "backend"
  
  host                   = module.eks_backend.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_backend.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks_backend.cluster_name,
      "--region",
      var.region
    ]
  }
}

# Provider for Gateway cluster (if needed)
provider "kubernetes" {
  alias = "gateway"
  
  host                   = module.eks_gateway.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks_gateway.cluster_certificate_authority_data)
  
  exec {
    api_version = "client.authentication.k8s.io/v1beta1"
    command     = "aws"
    args = [
      "eks",
      "get-token",
      "--cluster-name",
      module.eks_gateway.cluster_name,
      "--region",
      var.region
    ]
  }
}