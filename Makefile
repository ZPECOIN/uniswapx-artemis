# UniswapX Artemis Makefile
# Provides convenient commands for building, testing, and deploying

.PHONY: help build test clean run docker-build docker-run deploy monitor logs

# Default target
help:
	@echo "UniswapX Artemis - Available Commands"
	@echo "====================================="
	@echo "Development:"
	@echo "  build        Build the application"
	@echo "  test         Run tests"
	@echo "  clean        Clean build artifacts"
	@echo "  run          Run the application locally"
	@echo ""
	@echo "Docker:"
	@echo "  docker-build Build Docker image"
	@echo "  docker-run   Run with Docker Compose"
	@echo "  docker-stop  Stop Docker containers"
	@echo "  docker-logs  View Docker logs"
	@echo ""
	@echo "Deployment:"
	@echo "  deploy       Deploy with default settings"
	@echo "  deploy-dev   Deploy for development"
	@echo "  deploy-prod  Deploy for production"
	@echo "  deploy-aws   Deploy to AWS ECS"
	@echo "  deploy-k8s   Deploy to Kubernetes"
	@echo ""
	@echo "Monitoring:"
	@echo "  monitor      Run health checks"
	@echo "  logs         View application logs"
	@echo "  status       Check deployment status"
	@echo ""
	@echo "Environment:"
	@echo "  setup-env    Set up environment files"
	@echo "  check-deps   Check dependencies"

# Development commands
build:
	cargo build --release

test:
	cargo test --all-features

clean:
	cargo clean
	docker compose down --volumes --remove-orphans 2>/dev/null || true

run:
	cargo run

# Docker commands
docker-build:
	docker compose build

docker-run:
	docker compose up -d

docker-stop:
	docker compose down

docker-logs:
	docker compose logs -f artemis

# Deployment commands
deploy:
	./scripts/deploy.sh

deploy-dev:
	./scripts/deploy.sh -e development

deploy-prod:
	./scripts/deploy.sh -e production

deploy-aws:
	./scripts/deploy-aws.sh

deploy-k8s:
	./scripts/deploy-k8s.sh

# Monitoring commands
monitor:
	./scripts/monitor.sh

monitor-continuous:
	./scripts/monitor.sh -c

logs:
	@if docker compose ps | grep -q "artemis"; then \
		docker compose logs -f artemis; \
	elif kubectl get pods -l app=uniswapx-artemis 2>/dev/null | grep -q Running; then \
		kubectl logs -f -l app=uniswapx-artemis; \
	else \
		echo "No running deployment found"; \
	fi

status:
	@echo "Checking deployment status..."
	@if docker compose ps 2>/dev/null | grep -q "artemis"; then \
		echo "Docker Compose deployment found:"; \
		docker compose ps; \
	elif kubectl get pods -l app=uniswapx-artemis 2>/dev/null | grep -q .; then \
		echo "Kubernetes deployment found:"; \
		kubectl get pods -l app=uniswapx-artemis; \
	else \
		echo "No deployment found"; \
	fi

# Environment setup
setup-env:
	@if [ ! -f .env ]; then \
		if [ -f .env.development.example ]; then \
			cp .env.development.example .env; \
			echo "Created .env from .env.development.example"; \
		elif [ -f .env.example ]; then \
			cp .env.example .env; \
			echo "Created .env from .env.example"; \
		else \
			echo "No environment template found"; \
			exit 1; \
		fi; \
		echo "Please edit .env with your configuration"; \
	else \
		echo ".env already exists"; \
	fi

check-deps:
	@echo "Checking dependencies..."
	@command -v cargo >/dev/null 2>&1 || { echo "Error: cargo not installed"; exit 1; }
	@command -v docker >/dev/null 2>&1 || { echo "Warning: docker not installed"; }
	@command -v docker-compose >/dev/null 2>&1 || command -v docker >/dev/null 2>&1 && docker compose version >/dev/null 2>&1 || { echo "Warning: docker compose not available"; }
	@echo "Dependencies check completed"

# Utility commands
fmt:
	cargo fmt

clippy:
	cargo clippy -- -D warnings

check:
	cargo check

# Full CI pipeline
ci: check-deps test clippy fmt build
	@echo "CI pipeline completed successfully"