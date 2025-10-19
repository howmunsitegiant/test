.PHONY: help docker-build docker-up docker-down docker-logs docker-prod-build docker-prod-up prod-logs prod-setup aws-setup health

help:
	@echo "Laravel Docker Makefile Commands"
	@echo "================================"
	@echo ""
	@echo "Development:"
	@echo "  make docker-build      Build development image"
	@echo "  make docker-up         Start development container"
	@echo "  make docker-down       Stop development container"
	@echo "  make docker-logs       View development logs"
	@echo ""
	@echo "Production (Local):"
	@echo "  make docker-prod-build Build production image locally"
	@echo "  make docker-prod-up    Start production container locally"
	@echo "  make prod-logs         View production logs"
	@echo ""
	@echo "AWS/Deployment:"
	@echo "  make aws-setup         Setup AWS resources (requires AWS CLI)"
	@echo "  make health            Test /health endpoint"
	@echo ""

# Development
docker-build:
	docker-compose build app

docker-up:
	docker-compose up -d app
	@echo "Development container started at http://localhost"

docker-down:
	docker-compose down

docker-logs:
	docker-compose logs -f app

# Production (local testing)
docker-prod-build:
	docker-compose build app-prod

docker-prod-up:
	docker-compose up -d app-prod
	@echo "Production container started at http://localhost:8080"

prod-logs:
	docker-compose logs -f app-prod

# AWS Setup
aws-setup:
	@echo "Setting up AWS resources..."
	@bash docker/setup-aws.sh

# Health check
health:
	@echo "Checking health endpoints..."
	@echo "Development: http://localhost/health"
	@curl -s http://localhost/health || echo "Development container not running"
	@echo ""
	@echo "Production: http://localhost:8080/health"
	@curl -s http://localhost:8080/health || echo "Production container not running"
	@echo ""

# Cleanup
clean:
	docker-compose down -v
	docker system prune -f

# Shell access
shell-dev:
	docker-compose exec app sh

shell-prod:
	docker-compose exec app-prod sh

# Database
migrate:
	docker-compose exec app php artisan migrate

migrate-prod:
	docker-compose exec app-prod php artisan migrate

# Cache
cache-clear:
	docker-compose exec app php artisan cache:clear
	docker-compose exec app php artisan config:clear
	docker-compose exec app php artisan route:clear
	docker-compose exec app php artisan view:clear

cache-clear-prod:
	docker-compose exec app-prod php artisan cache:clear
	docker-compose exec app-prod php artisan config:clear
	docker-compose exec app-prod php artisan route:clear
	docker-compose exec app-prod php artisan view:clear
