#!/bin/bash

# UniswapX Artemis Monitoring Script
# Monitors the health and performance of the deployed application

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
DEPLOYMENT_TYPE="docker"  # docker, k8s, aws
NAMESPACE="default"
SERVICE_NAME="artemis"
CHECK_INTERVAL=30
CONTINUOUS=false

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -t, --type TYPE              Deployment type (docker, k8s, aws) [default: docker]"
    echo "  -n, --namespace NAMESPACE    Kubernetes namespace [default: default]"
    echo "  -s, --service SERVICE        Service name [default: artemis]"
    echo "  -i, --interval SECONDS       Check interval in seconds [default: 30]"
    echo "  -c, --continuous             Run continuously"
    echo "  -h, --help                   Show this help message"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            DEPLOYMENT_TYPE="$2"
            shift 2
            ;;
        -n|--namespace)
            NAMESPACE="$2"
            shift 2
            ;;
        -s|--service)
            SERVICE_NAME="$2"
            shift 2
            ;;
        -i|--interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        -c|--continuous)
            CONTINUOUS=true
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

# Function to check Docker deployment
check_docker() {
    print_status "Checking Docker deployment..."
    
    # Check if containers are running
    if docker compose ps | grep -q "Up"; then
        print_success "Docker containers are running"
        
        # Show container status
        echo "Container Status:"
        docker compose ps --format "table {{.Service}}\t{{.Status}}\t{{.Ports}}"
        
        # Check container health
        HEALTH=$(docker compose ps --format "{{.Service}} {{.Status}}" | grep artemis | awk '{print $2}')
        if [[ "$HEALTH" == *"healthy"* ]] || [[ "$HEALTH" == *"Up"* ]]; then
            print_success "Container is healthy"
        else
            print_warning "Container health check failed: $HEALTH"
        fi
        
        # Show resource usage
        echo ""
        print_status "Resource Usage:"
        docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
        
    else
        print_error "Docker containers are not running"
        return 1
    fi
}

# Function to check Kubernetes deployment
check_kubernetes() {
    print_status "Checking Kubernetes deployment..."
    
    # Check if kubectl is available
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        return 1
    fi
    
    # Check deployment status
    if kubectl get deployment uniswapx-artemis -n $NAMESPACE &> /dev/null; then
        print_success "Kubernetes deployment found"
        
        # Show deployment status
        echo "Deployment Status:"
        kubectl get deployment uniswapx-artemis -n $NAMESPACE -o wide
        
        # Show pod status
        echo ""
        echo "Pod Status:"
        kubectl get pods -l app=uniswapx-artemis -n $NAMESPACE -o wide
        
        # Check pod health
        READY_PODS=$(kubectl get pods -l app=uniswapx-artemis -n $NAMESPACE --no-headers | awk '{print $2}' | grep "1/1" | wc -l)
        TOTAL_PODS=$(kubectl get pods -l app=uniswapx-artemis -n $NAMESPACE --no-headers | wc -l)
        
        if [[ $READY_PODS -eq $TOTAL_PODS && $TOTAL_PODS -gt 0 ]]; then
            print_success "All pods are ready ($READY_PODS/$TOTAL_PODS)"
        else
            print_warning "Not all pods are ready ($READY_PODS/$TOTAL_PODS)"
        fi
        
        # Show resource usage
        echo ""
        print_status "Resource Usage:"
        kubectl top pods -l app=uniswapx-artemis -n $NAMESPACE 2>/dev/null || echo "Metrics server not available"
        
    else
        print_error "Kubernetes deployment not found"
        return 1
    fi
}

# Function to check AWS ECS deployment
check_aws() {
    print_status "Checking AWS ECS deployment..."
    
    # Check if AWS CLI is available
    if ! command -v aws &> /dev/null; then
        print_error "AWS CLI is not installed"
        return 1
    fi
    
    # Check service status
    CLUSTER_NAME="${CLUSTER_NAME:-uniswapx-artemis-cluster}"
    SERVICE_NAME="${ECS_SERVICE_NAME:-uniswapx-artemis-service}"
    
    if aws ecs describe-services --cluster $CLUSTER_NAME --services $SERVICE_NAME &> /dev/null; then
        print_success "ECS service found"
        
        # Show service status
        echo "Service Status:"
        aws ecs describe-services \
            --cluster $CLUSTER_NAME \
            --services $SERVICE_NAME \
            --query 'services[0].{Status:status,RunningCount:runningCount,DesiredCount:desiredCount,TaskDefinition:taskDefinition}' \
            --output table
        
        # Show task status
        echo ""
        echo "Task Status:"
        aws ecs list-tasks --cluster $CLUSTER_NAME --service-name $SERVICE_NAME \
            --query 'taskArns[0]' --output text | \
        xargs -I {} aws ecs describe-tasks --cluster $CLUSTER_NAME --tasks {} \
            --query 'tasks[0].{TaskArn:taskArn,LastStatus:lastStatus,HealthStatus:healthStatus,CreatedAt:createdAt}' \
            --output table
        
    else
        print_error "ECS service not found"
        return 1
    fi
}

# Function to show logs
show_logs() {
    echo ""
    print_status "Recent logs:"
    
    case $DEPLOYMENT_TYPE in
        docker)
            docker compose logs --tail=20 artemis
            ;;
        k8s)
            kubectl logs --tail=20 -l app=uniswapx-artemis -n $NAMESPACE
            ;;
        aws)
            echo "Use AWS CloudWatch to view logs"
            ;;
    esac
}

# Main monitoring function
run_checks() {
    echo "========================================"
    echo "UniswapX Artemis Health Check"
    echo "Time: $(date)"
    echo "Deployment Type: $DEPLOYMENT_TYPE"
    echo "========================================"
    
    case $DEPLOYMENT_TYPE in
        docker)
            check_docker
            ;;
        k8s)
            check_kubernetes
            ;;
        aws)
            check_aws
            ;;
        *)
            print_error "Unknown deployment type: $DEPLOYMENT_TYPE"
            exit 1
            ;;
    esac
    
    # Show logs on failure
    if [[ $? -ne 0 ]]; then
        show_logs
    fi
    
    echo ""
}

# Run monitoring
if [[ "$CONTINUOUS" == true ]]; then
    print_status "Starting continuous monitoring (interval: ${CHECK_INTERVAL}s)"
    print_status "Press Ctrl+C to stop"
    
    while true; do
        run_checks
        sleep $CHECK_INTERVAL
    done
else
    run_checks
fi