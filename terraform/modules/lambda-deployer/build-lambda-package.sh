#!/bin/bash
set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"

echo "Building Lambda deployment package..."

# Create temp directory
TEMP_DIR=$(mktemp -d)
LAMBDA_DIR="$TEMP_DIR/lambda"
LAYER_DIR="$TEMP_DIR/layer"

# Create Lambda function package
mkdir -p "$LAMBDA_DIR"
cp "$SCRIPT_DIR/lambda-code/orchestrator.py" "$LAMBDA_DIR/"

# Install Python dependencies if needed
pip install --target "$LAMBDA_DIR" boto3 2>/dev/null || true

# Create Lambda function zip
cd "$LAMBDA_DIR"
zip -r "$SCRIPT_DIR/lambda-code.zip" . -x "*.pyc" -x "__pycache__/*"

# Create kubectl layer
mkdir -p "$LAYER_DIR/bin"

# Download kubectl binary for Lambda (Linux x86_64)
echo "Downloading kubectl..."
curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl"
chmod +x kubectl
mv kubectl "$LAYER_DIR/bin/"

# Create layer zip
cd "$LAYER_DIR"
zip -r "$SCRIPT_DIR/kubectl-layer.zip" .

# Cleanup
rm -rf "$TEMP_DIR"

echo "Lambda packages created successfully!"
echo "  - lambda-code.zip"
echo "  - kubectl-layer.zip"