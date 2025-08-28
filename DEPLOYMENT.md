# UniswapX Artemis Deployment Guide

This guide provides comprehensive instructions for deploying UniswapX Artemis in various environments and platforms.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Configuration](#configuration)
3. [Local Deployment](#local-deployment)
4. [Docker Deployment](#docker-deployment)
5. [AWS ECS Deployment](#aws-ecs-deployment)
6. [Kubernetes Deployment](#kubernetes-deployment)
7. [Monitoring and Logs](#monitoring-and-logs)
8. [Troubleshooting](#troubleshooting)

## Prerequisites

### System Requirements
- Docker and Docker Compose
- Rust 1.81+ (for local builds)
- 2GB+ RAM
- 1+ CPU cores
- Network access to Ethereum RPC endpoints

### Required Information
- Ethereum RPC endpoints (HTTP and/or WebSocket)
- Private key or key management solution
- Deployed executor contract address
- Chain ID (1 for Ethereum mainnet)

## Configuration

### Environment Variables

Copy the appropriate environment file and configure your settings:

```bash
# For development
cp .env.development.example .env

# For production
cp .env.production.example .env
```

### Key Configuration Parameters

| Parameter | Description | Required | Example |
|-----------|-------------|----------|---------|
| `RPC_HTTP_URL` | Ethereum HTTP RPC endpoint | Yes | `https://eth-mainnet.g.alchemy.com/v2/KEY` |
| `RPC_WSS_URL` | Ethereum WebSocket RPC endpoint | Recommended | `wss://eth-mainnet.g.alchemy.com/v2/KEY` |
| `PRIVATE_KEY` | Private key for transactions | Yes* | `0x123...` |
| `PRIVATE_KEY_FILE` | Path to key file | Yes* | `/path/to/keyfile.json` |
| `AWS_SECRET_ARN` | AWS Secrets Manager ARN | Yes* | `arn:aws:secretsmanager:...` |
| `EXECUTOR_ADDRESS` | Deployed executor contract | Yes | `0x1234...` |
| `CHAIN_ID` | Blockchain network ID | Yes | `1` |
| `ORDER_TYPE` | Order type to process | Yes | `DutchV3` |
| `BID_PERCENTAGE` | Profit percentage for gas | No | `5` |

*One of the private key options is required.

### Security Best Practices

1. **Never commit private keys to version control**
2. **Use environment-specific configuration files**
3. **For production, use AWS Secrets Manager or equivalent**
4. **Rotate keys regularly**
5. **Use least-privilege principles**

## Local Deployment

### Using Cargo (Development)

1. Install Rust and dependencies:
```bash
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh
```

2. Configure environment:
```bash
cp .env.development.example .env
# Edit .env with your configuration
```

3. Run the application:
```bash
cargo run -- --help  # See available options
cargo run  # Uses environment variables
```

### Using Docker Compose

1. Configure environment:
```bash
cp .env.example .env
# Edit .env with your configuration
```

2. Deploy using the deployment script:
```bash
./scripts/deploy.sh
```

Or manually:
```bash
docker compose up -d
```

## Docker Deployment

### Quick Start

```bash
# Build and run with deployment script
./scripts/deploy.sh -e production

# Or build manually
docker compose build
docker compose up -d
```

### Custom Docker Build

```bash
# Build image
docker build -t uniswapx-artemis .

# Run with environment file
docker run --env-file .env uniswapx-artemis
```

### Docker Compose Options

The `compose.yaml` includes:
- Health checks
- Resource limits
- Security configurations
- Volume persistence
- Logging configuration

## AWS ECS Deployment

### Prerequisites

1. AWS CLI installed and configured
2. ECS cluster created
3. ECR repository created
4. Task definition created
5. Secrets stored in AWS Secrets Manager

### Deployment Steps

1. Set up AWS credentials:
```bash
aws configure
```

2. Deploy using the script:
```bash
./scripts/deploy-aws.sh \
  --aws-region us-east-1 \
  --cluster-name my-cluster \
  --service-name artemis-service \
  --ecr-repository my-repo
```

### AWS Configuration

Create the following AWS resources:

1. **ECS Cluster**: Fargate-based cluster
2. **ECR Repository**: For Docker images
3. **Task Definition**: With environment variables
4. **ECS Service**: For running tasks
5. **Secrets Manager**: For sensitive data
6. **IAM Roles**: For ECS task execution

## Kubernetes Deployment

### Prerequisites

1. kubectl installed and configured
2. Kubernetes cluster accessible
3. Docker image available in registry

### Deployment Steps

1. Update the Kubernetes manifests:
```bash
# Edit k8s/artemis-deployment.yaml
# Update image, secrets, and configuration
```

2. Deploy using the script:
```bash
./scripts/deploy-k8s.sh \
  --namespace artemis \
  --image-tag v1.0.0 \
  --docker-registry my-registry.com
```

Or manually:
```bash
kubectl apply -f k8s/artemis-deployment.yaml
```

### Kubernetes Configuration

The deployment includes:
- ConfigMap for non-sensitive configuration
- Secret for sensitive data
- Deployment with resource limits
- Service for network access
- Security contexts and policies

## Monitoring and Logs

### Docker Logs

```bash
# View logs
docker compose logs -f artemis

# View specific container logs
docker logs -f uniswapx-artemis
```

### Kubernetes Logs

```bash
# View deployment logs
kubectl logs -f deployment/uniswapx-artemis -n artemis

# View specific pod logs
kubectl logs -f pod/artemis-pod-name -n artemis
```

### AWS CloudWatch

When `CLOUDWATCH_METRICS=true`:
- Application metrics are sent to CloudWatch
- Custom dashboards can be created
- Alarms can be configured

### Health Checks

The application includes health checks:
- Docker: Process-based health check
- Kubernetes: Liveness and readiness probes
- AWS ECS: Container health checks

## Troubleshooting

### Common Issues

1. **Build Failures**
   ```bash
   # Clean and rebuild
   ./scripts/deploy.sh -c --no-cache
   ```

2. **Connection Issues**
   - Verify RPC endpoints are accessible
   - Check firewall and network settings
   - Validate API keys

3. **Permission Issues**
   - Verify private key has sufficient funds
   - Check contract permissions
   - Validate AWS IAM roles

4. **Container Issues**
   ```bash
   # Check container status
   docker compose ps
   
   # View detailed logs
   docker compose logs artemis
   
   # Restart services
   docker compose restart
   ```

### Health Check Commands

```bash
# Docker health check
docker compose ps

# Kubernetes health check
kubectl get pods -l app=uniswapx-artemis

# AWS ECS health check
aws ecs describe-services --cluster CLUSTER --services SERVICE
```

### Log Analysis

Look for these log patterns:
- `Starting deployment for environment: X` - Deployment start
- `UniswapX Artemis started successfully` - Successful start
- `Container is running` - Health confirmation
- Error patterns for troubleshooting

### Performance Monitoring

Monitor these metrics:
- CPU and memory usage
- Network connectivity
- Transaction success rate
- Gas usage and costs
- Order processing latency

## Support

For additional support:
1. Check the application logs first
2. Verify configuration settings
3. Test network connectivity
4. Review the GitHub repository for updates
5. Create an issue with detailed logs and configuration