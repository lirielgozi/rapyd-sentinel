# Use Amazon Linux 2023 as base (same as Lambda runtime)
# and manually add Lambda Runtime Interface Client
FROM amazonlinux:2023

# Install Python and system dependencies
RUN dnf update -y && \
    dnf install -y --allowerasing \
    python3.11 \
    python3.11-pip \
    curl \
    unzip \
    jq \
    && dnf clean all

# Install Lambda Runtime Interface Client and boto3
RUN python3.11 -m pip install --no-cache-dir awslambdaric boto3

# Install AWS CLI v2
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install && \
    rm -rf awscliv2.zip aws/

# Install kubectl
RUN curl -LO "https://dl.k8s.io/release/v1.28.0/bin/linux/amd64/kubectl" && \
    chmod +x kubectl && \
    mv kubectl /usr/local/bin/kubectl

# Set Lambda task root
ENV LAMBDA_TASK_ROOT=/var/task
RUN mkdir -p ${LAMBDA_TASK_ROOT}

# Copy Lambda function code and deploy script
COPY handler.py ${LAMBDA_TASK_ROOT}/
COPY deploy.sh ${LAMBDA_TASK_ROOT}/
RUN chmod +x ${LAMBDA_TASK_ROOT}/deploy.sh

# Set working directory
WORKDIR ${LAMBDA_TASK_ROOT}

# Set the entrypoint for Lambda Runtime Interface Client
ENTRYPOINT ["python3.11", "-m", "awslambdaric"]

# Set the CMD to your handler
CMD ["handler.lambda_handler"]