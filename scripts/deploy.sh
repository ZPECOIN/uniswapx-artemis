#!/bin/bash

# UniswapX Artemis Deployment Script
# This script provides automated deployment for different environments

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Default values
ENVIRONMENT="development"
BUILD_ONLY=false
CLEAN=false
NO_CACHE=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -e, --environment ENV    Set environment (development, production) [default: development]"
    echo "  -b, --build-only         Only build, don't run"
    echo "  -c, --clean             Clean build artifacts before building"
    echo "  --no-cache              Build without using Docker cache"
    echo "  -h, --help              Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0                                    # Deploy for development"
    echo "  $0 -e production                     # Deploy for production"
    echo "  $0 -b -e production                  # Build for production only"
    echo "  $0 -c --no-cache                     # Clean build with no cache"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -b|--build-only)
            BUILD_ONLY=true
            shift
            ;;
        -c|--clean)
            CLEAN=true
            shift
            ;;
        --no-cache)
            NO_CACHE=true
            shift
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

# Validate environment
if [[ ! "$ENVIRONMENT" =~ ^(development|production)$ ]]; then
    print_error "Invalid environment: $ENVIRONMENT"
    print_error "Supported environments: development, production"
    exit 1
fi

print_status "Starting deployment for environment: $ENVIRONMENT"

# Check if required files exist
if [[ ! -f "Dockerfile" ]]; then
    print_error "Dockerfile not found in current directory"
    exit 1
fi

if [[ ! -f "compose.yaml" ]]; then
    print_error "compose.yaml not found in current directory"
    exit 1
fi

# Check if environment file exists
ENV_FILE=".env.${ENVIRONMENT}"
if [[ ! -f ".env" && ! -f "$ENV_FILE" ]]; then
    print_warning "No .env or $ENV_FILE file found"
    print_warning "Please copy .env.example to .env and configure your settings"
    if [[ -f ".env.${ENVIRONMENT}.example" ]]; then
        print_status "You can use: cp .env.${ENVIRONMENT}.example .env"
    else
        print_status "You can use: cp .env.example .env"
    fi
    exit 1
fi

# Clean previous build artifacts if requested
if [[ "$CLEAN" == true ]]; then
    print_status "Cleaning previous build artifacts..."
    cargo clean || true
    docker compose down --volumes --remove-orphans || true
    docker system prune -f || true
    print_success "Cleanup completed"
fi

# Build Docker image
print_status "Building Docker image..."
BUILD_ARGS=""
if [[ "$NO_CACHE" == true ]]; then
    BUILD_ARGS="--no-cache"
fi

docker compose build $BUILD_ARGS
if [[ $? -eq 0 ]]; then
    print_success "Docker image built successfully"
else
    print_error "Failed to build Docker image"
    exit 1
fi

# Exit if build-only is requested
if [[ "$BUILD_ONLY" == true ]]; then
    print_success "Build completed. Exiting as requested."
    exit 0
fi

# Start the application
print_status "Starting UniswapX Artemis..."
docker compose up -d

if [[ $? -eq 0 ]]; then
    print_success "UniswapX Artemis started successfully"
    print_status "Container status:"
    docker compose ps
    print_status "To view logs: docker compose logs -f artemis"
    print_status "To stop: docker compose down"
else
    print_error "Failed to start UniswapX Artemis"
    exit 1
fi

# Show container health
sleep 5
print_status "Checking container health..."
HEALTH_STATUS=$(docker compose ps --format "table {{.Service}}\t{{.Status}}" | grep artemis | awk '{print $2}')
if [[ "$HEALTH_STATUS" == *"Up"* ]]; then
    print_success "Container is running"
else
    print_warning "Container may not be healthy. Check logs: docker compose logs artemis"
fi

print_success "Deployment completed for environment: $ENVIRONMENT"