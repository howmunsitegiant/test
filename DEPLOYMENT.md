# Laravel Docker Production Setup

This guide explains the production Docker setup for deploying this Laravel application to AWS ECS.

## Files Overview

### Production Dockerfile (Dockerfile.prod)
- **Multi-stage build** for minimal image size
- **ARM64 architecture** for AWS Graviton2/Graviton3 instances
- **Stage 1 (Builder)**: Builds dependencies, compiles assets, optimizes Laravel
- **Stage 2 (Runtime)**: Lightweight Alpine-based image with only runtime dependencies
- Includes PHP 8.3 FPM, Nginx, and Supervisord
- Final image size: ~350-400MB (compared to ~800MB+ without optimization)

### GitHub Actions Workflow (.github/workflows/build-deploy.yml)
Automatically:
1. Builds the Docker image using `Dockerfile.prod`
2. Pushes to Amazon ECR
3. Updates ECS task definition
4. Deploys to ECS service in `ap-southeast-1`

**Requirements:**
- AWS Account ID stored in `secrets.AWS_ACCOUNT_ID`
- IAM Role ARN stored in `secrets.AWS_ROLE_TO_ASSUME` (for OIDC)
- ECR repository named `howmun-test`
- ECS Cluster and Service named `howmun-test`

### Production Entrypoint (docker/entrypoint.prod.sh)
- Fetches `.env` from AWS Parameter Store (SSM)
- Runs database migrations
- Caches Laravel configuration and routes
- Optimizes application before startup

### ECS Task Definition (docker/ecs-task-definition.json)
- ARM64 runtime platform for AWS Graviton instances
- EC2-compatible (256 CPU, 512 memory) 
- Environment variables for AWS parameter fetching
- CloudWatch logging integration
- Health checks configured

### IAM Policy (docker/iam-policy.json)
Required permissions for ECS tasks to:
- Read from SSM Parameter Store
- Decrypt KMS keys (if parameters are encrypted)
- Write logs to CloudWatch

## Architecture Notes

This deployment is configured for **ARM64 architecture** to take advantage of AWS Graviton processors, which provide:
- Up to 40% better price-performance compared to x86-based instances
- Lower power consumption
- Better performance for many workloads

**ECS Instance Requirements:**
- Use ARM64-based EC2 instances (m6g, c6g, r6g, t4g families)
- Ensure your ECS cluster uses Graviton-based instances

## Setup Instructions

### 1. AWS Setup

#### Create Parameter Store Entry
```bash
# Store your .env content in AWS SSM Parameter Store
aws ssm put-parameter \
  --name /howmun-test \
  --type "SecureString" \
  --value "$(cat .env)" \
  --region ap-southeast-1
```

#### Create IAM Role for ECS Tasks
```bash
# Create task role
aws iam create-role \
  --role-name howmun-test-task-role \
  --assume-role-policy-document '{
    "Version": "2012-10-17",
    "Statement": [{
      "Effect": "Allow",
      "Principal": {"Service": "ecs-tasks.amazonaws.com"},
      "Action": "sts:AssumeRole"
    }]
  }'

# Attach policy
aws iam put-role-policy \
  --role-name howmun-test-task-role \
  --policy-name howmun-test-policy \
  --policy-document file://docker/iam-policy.json
```

#### Create ECR Repository
```bash
aws ecr create-repository \
  --repository-name howmun-test \
  --region ap-southeast-1
```

### 2. GitHub Setup

Add the following secrets to your GitHub repository:

- **AWS_ACCOUNT_ID**: Your 12-digit AWS Account ID
- **AWS_ROLE_TO_ASSUME**: ARN of IAM role with permissions to push to ECR and update ECS
  ```
  arn:aws:iam::794036769283:role/github-actions-role
  ```

### 3. Local Testing (Optional)

Build and test the production image locally:

```bash
# Build production image
docker-compose build app-prod

# Run production image
docker-compose up app-prod

# Access the application
curl http://localhost:8080
```

Note: Set `FETCH_ENV_FROM_AWS=false` locally to use local `.env` file.

## Deployment

### Automatic Deployment
Push to `main` branch → GitHub Actions automatically:
1. Builds and pushes to ECR
2. Updates ECS service
3. Waits for stable deployment

### Manual Deployment
Trigger workflow manually from GitHub Actions tab

## Monitoring

### View Logs
```bash
# CloudWatch logs
aws logs tail /ecs/howmun-test --follow --region ap-southeast-1

# Docker logs (local)
docker-compose logs -f app-prod
```

### Health Check
The container includes a health check that curls `/health` endpoint.

## Image Size Comparison

| Stage | Size |
|-------|------|
| Multi-stage with optimizations | ~350-400MB |
| Single-stage (without optimization) | ~800-1000MB |
| Reduction | ~55-60% |

## Environment Variables

### In ECS Task Definition
- `FETCH_ENV_FROM_AWS=true`: Enables fetching .env from Parameter Store
- `AWS_PARAM_NAME=/howmun-test`: Parameter Store path
- `AWS_REGION=ap-southeast-1`: AWS region
- `RUN_MIGRATIONS=true`: Run migrations on startup

### In Parameter Store
Store your complete `.env` file with all application secrets.

## Troubleshooting

### Image Build Fails
1. Ensure all required PHP extensions are listed in Dockerfile.prod
2. Check Node.js dependencies in `package.json`
3. Verify Composer dependencies in `composer.json`

### ECS Deployment Fails
1. Check IAM task role has SSM and KMS permissions
2. Verify Parameter Store value exists
3. Check CloudWatch logs for detailed error messages

### Health Check Fails
1. Ensure `/health` endpoint exists in `routes/web.php`
2. Check Nginx configuration in `docker/nginx/nginx.conf`
3. Verify PHP-FPM is running: `docker-compose exec app-prod supervisorctl status`

## Performance Tuning

### Scaling
Adjust in `docker/ecs-task-definition.json`:
- `cpu`: 1024 (0.5 CPU)
- `memory`: 2048 (2GB RAM)

### PHP-FPM Pools
Adjust in `docker/php/php-fpm.conf`:
- `pm.max_children`: Number of child processes
- `pm.start_servers`: Number to start initially
- `pm.max_spare_servers`: Maximum idle processes
