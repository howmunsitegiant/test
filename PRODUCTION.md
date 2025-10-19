# Laravel Docker Production Build Guide

## Overview

This project includes optimized Docker configurations for both development and production deployments:

- **Development**: `Dockerfile` - Full-featured with debugging and live reload
- **Production**: `Dockerfile.prod` - Minimal footprint, multi-stage build optimizations

## Quick Start

### Development

```bash
# Start development environment
make docker-up

# View logs
make docker-logs

# Stop
make docker-down
```

### Production (Local Testing)

```bash
# Build production image
make docker-prod-build

# Start production container
make docker-prod-up

# View logs
make prod-logs
```

## Production Deployment to ECS

### Prerequisites

1. AWS Account with IAM permissions
2. GitHub repository with this code
3. AWS CLI installed locally
4. Docker installed locally

### Step 1: Prepare AWS Environment

```bash
# Run setup script (requires AWS credentials configured)
make aws-setup

# Or run manually:
bash docker/setup-aws.sh
```

This creates:
- ✅ ECR repository (`howmun-test`)
- ✅ IAM role for ECS tasks
- ✅ CloudWatch log group
- ✅ ECS cluster (if needed)
- ✅ Stores `.env` in Parameter Store

### Step 2: Configure GitHub Actions

1. Go to your GitHub repository settings
2. Navigate to **Secrets and variables** → **Actions**
3. Add these secrets:
   - `AWS_ACCOUNT_ID`: `794036769283`
   - `AWS_ROLE_TO_ASSUME`: `arn:aws:iam::794036769283:role/github-actions-role`

See `.github/GITHUB_ACTIONS_SETUP.md` for detailed instructions.

### Step 3: Deploy

```bash
# Option A: Automatic (push to main)
git push origin main

# Option B: Manual trigger
# Go to GitHub → Actions → "Build and Deploy to ECS" → Run workflow

# Option C: Manual CLI
docker build -f Dockerfile.prod -t $ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/howmun-test .
docker push $ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/howmun-test
aws ecs update-service --cluster default --service howmun-test --force-new-deployment --region ap-southeast-1
```

## Architecture

### Docker Files

```
.
├── Dockerfile                          # Development image
├── Dockerfile.prod                     # Production image (multi-stage)
├── docker-compose.yml                  # Local orchestration
└── docker/
    ├── nginx/
    │   └── nginx.conf                 # Nginx reverse proxy config
    ├── php/
    │   ├── php.ini                    # PHP settings
    │   └── php-fpm.conf               # PHP-FPM pool config
    ├── supervisord/
    │   └── supervisord.conf           # Process manager config
    ├── entrypoint.sh                  # Dev/Local entrypoint
    ├── entrypoint.prod.sh             # Production entrypoint (AWS-aware)
    ├── ecs-task-definition.json       # ECS Fargate task config
    ├── iam-policy.json                # IAM permissions policy
    ├── setup-aws.sh                   # AWS resource setup script
    └── GITHUB_ACTIONS_SETUP.md        # Actions configuration guide
```

### GitHub Actions Workflow

**File**: `.github/workflows/build-deploy.yml`

**Triggers**:
- Push to `main` branch
- Manual trigger via GitHub Actions UI

**Steps**:
1. Checkout code
2. Configure AWS credentials (OIDC)
3. Login to Amazon ECR
4. Build Docker image (`Dockerfile.prod`)
5. Push to ECR with tags:
   - `latest` (for quick rollback)
   - `<commit-sha>` (for traceability)
6. Update ECS task definition
7. Deploy to ECS service
8. Wait for service stability

## Image Optimization

### Size Comparison

| Build Type | Size | Tech |
|-----------|------|------|
| Development | ~800-1000MB | Full PHP, node_modules, debugging tools |
| Production | ~350-400MB | Minimal Alpine, optimized layers |
| **Reduction** | **~55-60%** | Multi-stage builds + cleanup |

### Optimizations in Production Image

1. **Alpine Linux Base**: Smaller OS footprint
2. **Multi-stage Build**:
   - Stage 1: Builder (installs dependencies, builds assets)
   - Stage 2: Runtime (copies only built artifacts)
3. **Dependency Cleanup**: 
   - Removes `node_modules` after npm build
   - Removes build tools from runtime image
4. **Layer Caching**: Better reuse of Docker layers
5. **Composer Optimization**: `--optimize-autoloader --no-dev`
6. **Asset Pipeline**: Pre-built with Vite
7. **Config Caching**: Laravel configs pre-cached

## Environment Variables

### Development (.env local)
```bash
APP_ENV=local
APP_DEBUG=true
DB_CONNECTION=sqlite
FETCH_ENV_FROM_AWS=false
```

### Production (AWS Parameter Store)
```bash
APP_ENV=production
APP_DEBUG=false
DB_CONNECTION=mysql
FETCH_ENV_FROM_AWS=true
AWS_PARAM_NAME=/howmun-test
AWS_REGION=ap-southeast-1
RUN_MIGRATIONS=true
```

## Monitoring & Debugging

### View ECS Logs

```bash
# Real-time logs
aws logs tail /ecs/howmun-test --follow --region ap-southeast-1

# Last 100 lines
aws logs tail /ecs/howmun-test --region ap-southeast-1 --max-items 100
```

### Check ECS Service Status

```bash
aws ecs describe-services \
  --cluster default \
  --services howmun-test \
  --region ap-southeast-1
```

### Check Health Endpoint

```bash
# Development
curl http://localhost/health

# Production (local)
curl http://localhost:8080/health

# Production (AWS)
curl http://<ECS_SERVICE_URL>/health
```

### Container Shell Access

```bash
# Development
docker-compose exec app sh

# Production (local)
docker-compose exec app-prod sh
```

## Common Tasks

### Update Application

```bash
# Make changes to code
git add .
git commit -m "Update feature"

# Push to trigger automatic deployment
git push origin main

# Monitor deployment
aws logs tail /ecs/howmun-test --follow --region ap-southeast-1
```

### Run Migrations

```bash
# Development
make migrate

# Production (on ECS - automatic on startup if RUN_MIGRATIONS=true)
# Or manually:
aws ecs update-service --cluster default --service howmun-test --force-new-deployment --region ap-southeast-1
```

### Clear Caches

```bash
# Development
make cache-clear

# Production (local)
make cache-clear-prod
```

### Update Database Connection

1. Update `.env` in local repo
2. Store in Parameter Store:
   ```bash
   aws ssm put-parameter \
     --name /howmun-test \
     --type SecureString \
     --value "$(cat .env)" \
     --overwrite \
     --region ap-southeast-1
   ```
3. Restart ECS task to pick up changes

## Troubleshooting

### Build Fails: PHP Extension Missing
**Error**: `Extension not found`

**Solution**: Add to Dockerfile.prod
```dockerfile
RUN docker-php-ext-install <extension>
```

### Deployment Fails: Role Assumption Error
**Error**: `NotAuthorizedException` or `AccessDenied`

**Solution**: 
- Check GitHub Actions secrets are set
- Verify IAM role trust policy includes GitHub token provider
- See `.github/GITHUB_ACTIONS_SETUP.md`

### Health Check Fails
**Error**: Container restarts repeatedly

**Solutions**:
1. Check `/health` route exists: `routes/web.php`
2. Check Nginx config: `docker/nginx/nginx.conf`
3. Check PHP-FPM running: `docker-compose exec app-prod supervisorctl status`

### Performance Issues
**Symptoms**: Slow response times, high CPU

**Solutions**:
1. Increase ECS task resources in `docker/ecs-task-definition.json`
2. Adjust PHP-FPM pools in `docker/php/php-fpm.conf`
3. Check CloudWatch logs for errors
4. Enable Query debugging in Laravel

### Storage/Permissions Issues
**Error**: `Permission denied` writing to storage

**Causes**: 
- Storage directory not writable
- Wrong file ownership

**Solution**:
```bash
# In container
docker-compose exec app chown -R www-data:www-data storage bootstrap/cache
docker-compose exec app chmod -R 775 storage bootstrap/cache
```

## Security Notes

1. **Parameter Store**: Uses KMS encryption by default
2. **Secrets**: Never commit `.env` to git
3. **IAM Roles**: Follow least-privilege principle
4. **OIDC**: GitHub Actions uses OpenID Connect (no long-lived credentials)
5. **Health Endpoint**: Consider adding authentication in production

## Performance Tuning

### PHP-FPM Configuration

Edit `docker/php/php-fpm.conf`:

```ini
# Increase worker processes
pm.max_children = 50          # Max concurrent requests
pm.start_servers = 10         # Initial workers
pm.min_spare_servers = 5      # Minimum idle workers
pm.max_spare_servers = 20     # Maximum idle workers
```

### ECS Task Resources

Edit `docker/ecs-task-definition.json`:

```json
{
  "cpu": "2048",              // Increase from 1024
  "memory": "4096"            // Increase from 2048
}
```

### Nginx Settings

Edit `docker/nginx/nginx.conf`:

```nginx
worker_processes auto;         // Auto-detect CPU count
worker_connections 4096;       // Increase from 1024
```

## References

- [Laravel Documentation](https://laravel.com/docs)
- [Docker Best Practices](https://docs.docker.com/develop/dev-best-practices/)
- [AWS ECS Documentation](https://docs.aws.amazon.com/ecs/)
- [GitHub Actions Documentation](https://docs.github.com/actions)

## Support

For issues or questions:
1. Check the troubleshooting section above
2. Review GitHub Actions logs
3. Check CloudWatch logs
4. Check container logs: `docker-compose logs app-prod`
