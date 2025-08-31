output "function_name" {
  description = "Name of the Lambda function"
  value       = aws_lambda_function.deployer.function_name
}

output "function_arn" {
  description = "ARN of the Lambda function"
  value       = aws_lambda_function.deployer.arn
}

output "function_invoke_arn" {
  description = "Invoke ARN of the Lambda function"
  value       = aws_lambda_function.deployer.invoke_arn
}

output "role_arn" {
  description = "ARN of the Lambda execution role"
  value       = local.lambda_role_arn
}

output "security_group_id" {
  description = "Security group ID of the Lambda function"
  value       = aws_security_group.lambda.id
}

output "ecr_repository_url" {
  description = "ECR repository URL for the Lambda container image"
  value       = aws_ecr_repository.lambda.repository_url
}