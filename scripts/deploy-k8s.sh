#!/bin/bash

# Kubernetes Deployment Script for UniswapX Artemis

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
NAMESPACE="${NAMESPACE:-default}"
IMAGE_TAG="${IMAGE_TAG:-latest}"
DOCKER_REGISTRY="${DOCKER_REGISTRY:-}"

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --namespace NAMESPACE         Kubernetes namespace [default: default]"
    echo "  --image-tag TAG               Docker image tag [default: latest]"
    echo "  --docker-registry REGISTRY   Docker registry URL"
    echo "  -h, --help                    Show this help message"
    echo ""
    echo "Prerequisites:"
    echo "  - kubectl installed and configured"
    echo "  - Docker image built and available"
    echo "  - Kubernetes cluster accessible"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        --image-tag)
            IMAGE_TAG="$2"
            shift 2
            ;;
        --docker-registry)
            DOCKER_REGISTRY="$2"
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

print_status "Starting Kubernetes deployment..."
print_status "Namespace: $NAMESPACE"
print_status "Image Tag: $IMAGE_TAG"

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    print_error "kubectl is not installed"
    exit 1
fi

# Check kubectl connectivity
print_status "Checking kubectl connectivity..."
if ! kubectl cluster-info &> /dev/null; then
    print_error "Cannot connect to Kubernetes cluster"
    exit 1
fi

# Create namespace if it doesn't exist
print_status "Ensuring namespace exists..."
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# Update image in deployment manifest
DEPLOYMENT_FILE="k8s/artemis-deployment.yaml"
if [[ ! -f "$DEPLOYMENT_FILE" ]]; then
    print_error "Deployment file not found: $DEPLOYMENT_FILE"
    exit 1
fi

# Create a temporary deployment file with updated image
TEMP_DEPLOYMENT=$(mktemp)
cp "$DEPLOYMENT_FILE" "$TEMP_DEPLOYMENT"

# Update image name
if [[ -n "$DOCKER_REGISTRY" ]]; then
    IMAGE_NAME="${DOCKER_REGISTRY}/uniswapx-artemis:${IMAGE_TAG}"
else
    IMAGE_NAME="uniswapx-artemis:${IMAGE_TAG}"
fi

sed -i "s|image: uniswapx-artemis:latest|image: ${IMAGE_NAME}|g" "$TEMP_DEPLOYMENT"
sed -i "s|namespace: default|namespace: ${NAMESPACE}|g" "$TEMP_DEPLOYMENT"

print_status "Deploying to Kubernetes..."
kubectl apply -f "$TEMP_DEPLOYMENT" -n $NAMESPACE

# Clean up temp file
rm "$TEMP_DEPLOYMENT"

# Wait for deployment to be ready
print_status "Waiting for deployment to be ready..."
kubectl rollout status deployment/uniswapx-artemis -n $NAMESPACE --timeout=300s

if [[ $? -eq 0 ]]; then
    print_success "Deployment completed successfully"
    
    # Show deployment status
    print_status "Deployment status:"
    kubectl get deployments -n $NAMESPACE | grep uniswapx-artemis
    
    print_status "Pod status:"
    kubectl get pods -n $NAMESPACE -l app=uniswapx-artemis
    
    print_status "Service status:"
    kubectl get services -n $NAMESPACE | grep uniswapx-artemis
else
    print_error "Deployment failed or timed out"
    exit 1
fi

print_success "Kubernetes deployment completed"
print_status "To view logs: kubectl logs -f deployment/uniswapx-artemis -n $NAMESPACE"
print_status "To delete deployment: kubectl delete -f k8s/artemis-deployment.yaml -n $NAMESPACE"