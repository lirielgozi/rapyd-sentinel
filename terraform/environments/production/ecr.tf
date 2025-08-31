# ECR Repositories for container images
resource "aws_ecr_repository" "backend" {
  name                 = "${var.project_name}/backend"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Allow deletion even with images

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-backend"
      Type = "backend"
    }
  )
}

resource "aws_ecr_repository" "gateway" {
  name                 = "${var.project_name}/gateway"
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Allow deletion even with images

  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = merge(
    local.common_tags,
    {
      Name = "${var.project_name}-gateway"
      Type = "gateway"
    }
  )
}

# Lifecycle policies to clean up old images
resource "aws_ecr_lifecycle_policy" "backend" {
  repository = aws_ecr_repository.backend.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

resource "aws_ecr_lifecycle_policy" "gateway" {
  repository = aws_ecr_repository.gateway.name

  policy = jsonencode({
    rules = [
      {
        rulePriority = 1
        description  = "Keep last 10 images"
        selection = {
          tagStatus     = "any"
          countType     = "imageCountMoreThan"
          countNumber   = 10
        }
        action = {
          type = "expire"
        }
      }
    ]
  })
}

# Docker builds for backend and gateway services
# These run after ECR repositories are created

resource "null_resource" "backend_docker_build" {
  triggers = {
    dockerfile_hash = filemd5("${path.module}/../../../kubernetes/backend/Dockerfile")
    always_run      = timestamp() # Force rebuild on every apply
  }

  provisioner "local-exec" {
    command = <<EOF
      set -e
      echo "Building backend Docker image..."
      
      # Build the Docker image
      docker build -t ${aws_ecr_repository.backend.repository_url}:latest \
        ${path.module}/../../../kubernetes/backend/
      
      # Get ECR login token
      aws ecr get-login-password --region ${var.region} | \
        docker login --username AWS --password-stdin ${data.aws_caller_identity.current.account_id}.dkr.ecr.${var.region}.amazonaws.com
      
      # Push the latest tag
      docker push ${aws_ecr_repository.backend.repository_url}:latest
      
      echo "Backend Docker image pushed successfully"
    EOF
  }

  # Ensure ECR repository exists before building
  depends_on = [
    aws_ecr_repository.backend
  ]
}

# Gateway Docker build removed - using nginx:alpine directly with dynamic configuration

