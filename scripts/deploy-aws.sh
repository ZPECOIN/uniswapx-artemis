#!/bin/bash

# AWS ECS Deployment Script for UniswapX Artemis
# Deploys the application to AWS ECS using Fargate

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() { echo -e "${BLUE}[INFO]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
AWS_REGION="${AWS_REGION:-us-east-1}"
CLUSTER_NAME="${CLUSTER_NAME:-uniswapx-artemis-cluster}"
SERVICE_NAME="${SERVICE_NAME:-uniswapx-artemis-service}"
TASK_DEFINITION_NAME="${TASK_DEFINITION_NAME:-uniswapx-artemis-task}"
ECR_REPOSITORY="${ECR_REPOSITORY:-uniswapx-artemis}"
IMAGE_TAG="${IMAGE_TAG:-latest}"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --aws-region REGION           AWS region [default: us-east-1]"
    echo "  --cluster-name NAME           ECS cluster name"
    echo "  --service-name NAME           ECS service name"
    echo "  --task-definition NAME        Task definition name"
    echo "  --ecr-repository NAME         ECR repository name"
    echo "  --image-tag TAG               Docker image tag [default: latest]"
    echo "  -h, --help                    Show this help message"
    echo ""
    echo "Environment Variables:"
    echo "  AWS_REGION                    AWS region"
    echo "  AWS_ACCESS_KEY_ID             AWS access key"
    echo "  AWS_SECRET_ACCESS_KEY         AWS secret key"
    echo ""
    echo "Prerequisites:"
    echo "  - AWS CLI installed and configured"
    echo "  - Docker installed"
    echo "  - ECS cluster created"
    echo "  - ECR repository created"
    echo "  - Task definition created"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --aws-region)
            AWS_REGION="$2"
            shift 2
            ;;
        --cluster-name)
            CLUSTER_NAME="$2"
            shift 2
            ;;
        --service-name)
            SERVICE_NAME="$2"
            shift 2
            ;;
        --task-definition)
            TASK_DEFINITION_NAME="$2"
            shift 2
            ;;
        --ecr-repository)
            ECR_REPOSITORY="$2"
            shift 2
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        -h|--help)
            show_usage
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
done

print_status "Starting AWS ECS deployment..."
print_status "Region: $AWS_REGION"
print_status "Cluster: $CLUSTER_NAME"
print_status "Service: $SERVICE_NAME"
print_status "ECR Repository: $ECR_REPOSITORY"
print_status "Image Tag: $IMAGE_TAG"

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null; then
    print_error "AWS CLI is not installed"
    exit 1
fi

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed"
    exit 1
fi

# Get AWS account ID
print_status "Getting AWS account ID..."
AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
if [[ $? -ne 0 ]]; then
    print_error "Failed to get AWS account ID. Please check your AWS credentials."
    exit 1
fi
print_status "AWS Account ID: $AWS_ACCOUNT_ID"

# ECR repository URI
ECR_URI="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"

# Login to ECR
print_status "Logging in to ECR..."
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com
if [[ $? -ne 0 ]]; then
    print_error "Failed to login to ECR"
    exit 1
fi

# Build and tag Docker image
print_status "Building Docker image..."
docker build -t ${ECR_REPOSITORY}:${IMAGE_TAG} .
if [[ $? -ne 0 ]]; then
    print_error "Failed to build Docker image"
    exit 1
fi

# Tag image for ECR
print_status "Tagging image for ECR..."
docker tag ${ECR_REPOSITORY}:${IMAGE_TAG} ${ECR_URI}

# Push image to ECR
print_status "Pushing image to ECR..."
docker push ${ECR_URI}
if [[ $? -ne 0 ]]; then
    print_error "Failed to push image to ECR"
    exit 1
fi
print_success "Image pushed to ECR: ${ECR_URI}"

# Update ECS service
print_status "Updating ECS service..."
aws ecs update-service \
    --cluster $CLUSTER_NAME \
    --service $SERVICE_NAME \
    --force-new-deployment \
    --region $AWS_REGION
if [[ $? -ne 0 ]]; then
    print_error "Failed to update ECS service"
    exit 1
fi

print_status "Waiting for service to reach stable state..."
aws ecs wait services-stable \
    --cluster $CLUSTER_NAME \
    --services $SERVICE_NAME \
    --region $AWS_REGION

if [[ $? -eq 0 ]]; then
    print_success "Service updated successfully"
    
    # Get service status
    print_status "Service status:"
    aws ecs describe-services \
        --cluster $CLUSTER_NAME \
        --services $SERVICE_NAME \
        --region $AWS_REGION \
        --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount}'
else
    print_warning "Service update may have issues. Check ECS console for details."
fi

print_success "AWS ECS deployment completed"
print_status "ECR Image: ${ECR_URI}"
print_status "ECS Service: ${SERVICE_NAME}"
print_status "ECS Cluster: ${CLUSTER_NAME}"