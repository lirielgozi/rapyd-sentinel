# Security group for Lambda
resource "aws_security_group" "lambda" {
  name        = "${var.function_name}-sg"
  description = "Security group for Lambda deployment function"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
    description = "Allow all outbound traffic"
  }

  tags = var.tags
}