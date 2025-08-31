# Output the Lambda role ARN so it can be added to aws-auth ConfigMap
output "lambda_role_arn" {
  description = "ARN of the Lambda execution role (needs to be added to EKS aws-auth)"
  value       = local.lambda_role_arn
}

# Note: The Lambda role needs to be added to the EKS aws-auth ConfigMap
# This should be done in the EKS module or main configuration