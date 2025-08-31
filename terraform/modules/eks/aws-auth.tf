# Configure Kubernetes provider for this cluster
terraform {
  required_providers {
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.23"
    }
  }
}

# Data source for EKS authentication
data "aws_eks_cluster_auth" "main" {
  name = aws_eks_cluster.main.name
}

# Configure aws-auth ConfigMap using Kubernetes provider
# Use kubernetes_config_map_v1_data to patch existing ConfigMap created by EKS
resource "kubernetes_config_map_v1_data" "aws_auth" {
  count = var.manage_aws_auth ? 1 : 0

  metadata {
    name      = "aws-auth"
    namespace = "kube-system"
  }

  data = {
    mapRoles = yamlencode(
      concat(
        [
          {
            rolearn  = aws_iam_role.eks_nodes.arn
            username = "system:node:{{EC2PrivateDNSName}}"
            groups   = [
              "system:bootstrappers",
              "system:nodes"
            ]
          }
        ],
        var.additional_iam_roles
      )
    )
  }

  force = true

  depends_on = [
    aws_eks_cluster.main,
    aws_eks_node_group.main
  ]
}

# Variables for aws-auth configuration
variable "manage_aws_auth" {
  description = "Whether to manage the aws-auth ConfigMap"
  type        = bool
  default     = false
}

variable "additional_iam_roles" {
  description = "Additional IAM roles to add to the aws-auth ConfigMap"
  type = list(object({
    rolearn  = string
    username = string
    groups   = list(string)
  }))
  default = []
}