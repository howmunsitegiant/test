# Quick Reference: Laravel Docker Production Setup

## TL;DR - Get Started in 5 Minutes

```bash
# 1. Setup AWS resources
make aws-setup

# 2. Add GitHub secrets (AWS_ACCOUNT_ID, AWS_ROLE_TO_ASSUME)
# → Go to GitHub repo → Settings → Secrets and variables → Actions

# 3. Deploy
git push origin main

# 4. Monitor
aws logs tail /ecs/howmun-test --follow --region ap-southeast-1
```

## File Map

| File | Purpose |
|------|---------|
| `Dockerfile` | Development - full featured |
| `Dockerfile.prod` | Production - optimized (~350MB) |
| `docker-compose.yml` | Local dev/prod orchestration |
| `.github/workflows/build-deploy.yml` | GitHub Actions CI/CD |
| `docker/nginx/nginx.conf` | Web server config |
| `docker/php/php-fpm.conf` | PHP worker config |
| `docker/supervisord/supervisord.conf` | Process manager |
| `docker/entrypoint.prod.sh` | Production startup (fetches .env from AWS) |
| `docker/ecs-task-definition.json` | ECS Fargate config |
| `docker/iam-policy.json` | AWS permissions |
| `docker/setup-aws.sh` | AWS resource setup |
| `.github/GITHUB_ACTIONS_SETUP.md` | Actions configuration |
| `DEPLOYMENT.md` | Full deployment guide |
| `PRODUCTION.md` | Production reference |

## Commands Cheatsheet

### Development
```bash
make docker-build           # Build dev image
make docker-up              # Start dev container
make docker-logs            # View dev logs
make docker-down            # Stop dev container
make shell-dev              # Shell into dev container
```

### Production (Local Testing)
```bash
make docker-prod-build      # Build prod image
make docker-prod-up         # Start prod container
make prod-logs              # View prod logs
make shell-prod             # Shell into prod container
```

### AWS & Deployment
```bash
make aws-setup              # Setup AWS resources
make health                 # Test health endpoints
aws logs tail /ecs/howmun-test --follow --region ap-southeast-1
```

## Architecture Overview

```
GitHub Push → GitHub Actions → Build Docker Image → Push to ECR 
                                                        ↓
                                                    ECS Update
                                                        ↓
                                                  Update Service
                                                        ↓
                                              New Tasks Running
                                                        ↓
                                            Health Check Passes
```

## Key AWS Resources

| Resource | Name | Region |
|----------|------|--------|
| ECR Repository | `howmun-test` | ap-southeast-1 |
| ECS Cluster | `default` | ap-southeast-1 |
| ECS Service | `howmun-test` | ap-southeast-1 |
| Parameter Store | `/howmun-test` | ap-southeast-1 |
| IAM Role (Task) | `howmun-test-task-role` | Global |
| IAM Role (GitHub) | `github-actions-role` | Global |
| CloudWatch Logs | `/ecs/howmun-test` | ap-southeast-1 |

## Workflow

### First Time Setup
```
1. Clone repo
2. Run: make aws-setup
3. Add GitHub secrets
4. Push to main
5. Check: aws logs tail /ecs/howmun-test --follow
```

### Regular Deployment
```
1. Make code changes
2. git push origin main
3. Automatic build → ECR → ECS
4. Done! (Health checks ensure stability)
```

### Manual Override
```bash
# If automated deployment fails:
docker build -f Dockerfile.prod -t ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/howmun-test .
docker push ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/howmun-test
aws ecs update-service --cluster default --service howmun-test --force-new-deployment --region ap-southeast-1
```

## Environment Variables

### Local Development (`.env`)
```
APP_ENV=local
APP_DEBUG=true
DB_CONNECTION=sqlite
```

### Production (AWS Parameter Store - `/howmun-test`)
```
APP_ENV=production
APP_DEBUG=false
DB_CONNECTION=mysql
FETCH_ENV_FROM_AWS=true
```

## Image Size

| Scenario | Size |
|----------|------|
| Development | ~800-1000MB |
| Production | ~350-400MB |
| Saved | ~450-650MB (55-60%) |

## Status Checks

```bash
# Check AWS resources
aws ecr describe-repositories --region ap-southeast-1
aws ecs describe-services --cluster default --services howmun-test --region ap-southeast-1

# Check health
curl http://localhost/health              # Dev
curl http://localhost:8080/health         # Prod (local)

# Check logs
docker-compose logs app                   # Dev
docker-compose logs app-prod              # Prod (local)
aws logs tail /ecs/howmun-test --follow   # Prod (AWS)
```

## Troubleshooting Quick Fixes

| Issue | Fix |
|-------|-----|
| Build fails | Check `Dockerfile.prod` layers, verify extensions |
| GitHub Actions fails | Check secrets, verify AWS IAM role |
| ECS deployment fails | Check CloudWatch logs, verify health check |
| Slow performance | Increase ECS task CPU/memory |
| Permission denied | Run `chmod 775 storage bootstrap/cache` |

## Important Files to Update

- **AWS Account ID**: Update in `docker/iam-policy.json`, `docker/ecs-task-definition.json`
- **GitHub Secrets**: Update `AWS_ACCOUNT_ID` and `AWS_ROLE_TO_ASSUME`
- **Environment Variables**: Store in AWS Parameter Store, not in code
- **Health Endpoint**: Ensure `/health` route exists (added to `routes/web.php`)

## Next Steps

1. ✅ Review `Dockerfile.prod` - understand multi-stage optimization
2. ✅ Run `make aws-setup` - create AWS resources
3. ✅ Add GitHub secrets - configure CI/CD
4. ✅ Push to main - trigger first deployment
5. ✅ Monitor logs - verify deployment success
6. ✅ Test health endpoint - confirm application running

## Documentation

- `PRODUCTION.md` - Comprehensive production guide
- `DEPLOYMENT.md` - Detailed deployment instructions
- `.github/GITHUB_ACTIONS_SETUP.md` - GitHub Actions configuration
- `Makefile` - All available commands
