# Build and push Lambda Docker image to ECR

# Create ECR repository for Lambda image
resource "aws_ecr_repository" "lambda" {
  name                 = var.function_name
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Allow deletion even with images

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = var.tags
}

# ECR lifecycle policy
resource "aws_ecr_lifecycle_policy" "lambda" {
  repository = aws_ecr_repository.lambda.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 5 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 5
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Build and push Docker image
resource "null_resource" "docker_build" {
  triggers = {
    # Rebuild when any of these files change
    dockerfile_hash = filemd5("${path.module}/docker/Dockerfile")
    handler_hash    = filemd5("${path.module}/docker/handler.py")
    deploy_sh_hash  = filemd5("${path.module}/docker/deploy.sh")
    always_run      = timestamp() # Force rebuild on every apply
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Building Lambda Docker image..."
      
      # Get ECR repository URL
      ECR_URL="${aws_ecr_repository.lambda.repository_url}"
      ECR_REGISTRY="$(echo $ECR_URL | cut -d'/' -f1)"
      
      # Ensure Docker daemon is running
      if ! docker info >/dev/null 2>&1; then
        echo "Error: Docker daemon is not running"
        exit 1
      fi
      
      # Login to ECR with retry
      echo "Logging into ECR..."
      for i in 1 2 3; do
        if aws ecr get-login-password --region ${var.region} | docker login --username AWS --password-stdin $ECR_REGISTRY; then
          echo "Successfully logged into ECR"
          break
        else
          echo "ECR login attempt $i failed, retrying..."
          sleep 5
        fi
      done
      
      # Build Docker image
      echo "Building Docker image..."
      cd ${path.module}/docker
      docker build -t ${var.function_name} .
      
      # Tag image for ECR
      IMAGE_TAG="$(date +%Y%m%d%H%M%S)"
      docker tag ${var.function_name}:latest $ECR_URL:latest
      docker tag ${var.function_name}:latest $ECR_URL:$IMAGE_TAG
      
      # Push to ECR with retry
      echo "Pushing to ECR..."
      for i in 1 2 3; do
        if docker push $ECR_URL:latest && docker push $ECR_URL:$IMAGE_TAG; then
          echo "Successfully pushed to ECR"
          break
        else
          echo "Push attempt $i failed, retrying..."
          sleep 5
        fi
      done
      
      echo "Lambda Docker image pushed successfully to $ECR_URL"
    EOT
  }

  depends_on = [
    aws_ecr_repository.lambda
  ]
}

# Update Lambda function with new container image
resource "null_resource" "lambda_update" {
  triggers = {
    # Trigger update whenever Docker image is rebuilt
    docker_build_id = null_resource.docker_build.id
    always_run      = timestamp() # Force update on every apply
  }

  provisioner "local-exec" {
    command = <<-EOT
      set -e
      
      echo "Updating Lambda function with new container image..."
      
      # Wait for Docker build to complete
      sleep 5
      
      # Update Lambda function code
      echo "Updating Lambda function ${aws_lambda_function.deployer.function_name}..."
      aws lambda update-function-code \
        --function-name ${aws_lambda_function.deployer.function_name} \
        --image-uri ${aws_ecr_repository.lambda.repository_url}:latest \
        --region ${var.region} \
        --output json > /tmp/lambda-update.json
      
      # Wait for update to complete
      echo "Waiting for Lambda update to complete..."
      for i in {1..30}; do
        STATUS=$(aws lambda get-function \
          --function-name ${aws_lambda_function.deployer.function_name} \
          --region ${var.region} \
          --query 'Configuration.LastUpdateStatus' \
          --output text)
        
        if [ "$STATUS" = "Successful" ]; then
          echo "Lambda function updated successfully"
          break
        elif [ "$STATUS" = "Failed" ]; then
          echo "Lambda update failed!"
          exit 1
        else
          echo "Update status: $STATUS (attempt $i/30)"
          sleep 5
        fi
      done
      
      # Verify Lambda is active
      STATE=$(aws lambda get-function \
        --function-name ${aws_lambda_function.deployer.function_name} \
        --region ${var.region} \
        --query 'Configuration.State' \
        --output text)
      
      if [ "$STATE" = "Active" ]; then
        echo "Lambda function is active and ready"
      else
        echo "Warning: Lambda function state is $STATE"
      fi
    EOT
  }

  depends_on = [
    null_resource.docker_build,
    aws_lambda_function.deployer
  ]
}