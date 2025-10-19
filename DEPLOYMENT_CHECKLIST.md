# Production Deployment Checklist

Complete this checklist to get your Laravel application running on AWS ECS.

## Pre-Deployment Setup

- [ ] **Review Documentation**
  - [ ] Read `QUICKSTART.md` for quick overview
  - [ ] Read `PRODUCTION.md` for comprehensive guide
  - [ ] Review `GITHUB_ACTIONS_SETUP.md` for Actions config

- [ ] **Local Testing**
  - [ ] Run `make docker-build` to build development image
  - [ ] Run `make docker-up` to start development container
  - [ ] Test application at http://localhost
  - [ ] Run `make docker-prod-build` to build production image
  - [ ] Run `make docker-prod-up` to start production container locally
  - [ ] Test application at http://localhost:8080
  - [ ] Run `make health` to test health endpoints

- [ ] **Code Quality**
  - [ ] Run any linters/tests locally
  - [ ] Ensure code is committed to git
  - [ ] Push to `main` branch or create PR

## AWS Setup

- [ ] **Configure AWS CLI**
  - [ ] Install AWS CLI: `pip install awscli`
  - [ ] Configure credentials: `aws configure`
  - [ ] Verify region is set to `ap-southeast-1`

- [ ] **Create AWS Resources**
  - [ ] Run `make aws-setup`
  - [ ] Verify ECR repository created: `aws ecr describe-repositories --region ap-southeast-1`
  - [ ] Verify IAM role created: `aws iam get-role --role-name howmun-test-task-role`
  - [ ] Verify Parameter Store: `aws ssm get-parameter --name /howmun-test --region ap-southeast-1`
  - [ ] Verify CloudWatch log group: `aws logs describe-log-groups --region ap-southeast-1 | grep howmun-test`

- [ ] **Verify IAM Permissions**
  - [ ] Check that task role has SSM and KMS permissions
  - [ ] Verify Parameter Store value is encrypted (SecureString)
  - [ ] Create execution role if it doesn't exist: `ecsTaskExecutionRole`

## GitHub Setup

- [ ] **Create GitHub Secrets**
  - [ ] Go to GitHub repo Settings → Secrets and variables → Actions
  - [ ] Add secret: `AWS_ACCOUNT_ID` = `794036769283`
  - [ ] Add secret: `AWS_ROLE_TO_ASSUME` = `arn:aws:iam::794036769283:role/github-actions-role`
  - [ ] Verify secrets are set (don't show the values)

- [ ] **Verify GitHub Actions Workflow**
  - [ ] Go to Actions tab
  - [ ] Confirm `build-deploy.yml` workflow exists
  - [ ] Check workflow file is valid YAML

- [ ] **Create GitHub Actions IAM Role**
  - [ ] Create IAM role with OIDC trust policy (see `GITHUB_ACTIONS_SETUP.md`)
  - [ ] Attach ECR and ECS permissions
  - [ ] Role name: `github-actions-role`

## First Deployment

- [ ] **Push to Main**
  - [ ] Ensure all changes committed
  - [ ] Push to `main` branch: `git push origin main`
  - [ ] GitHub Actions should automatically trigger

- [ ] **Monitor GitHub Actions**
  - [ ] Go to Actions tab
  - [ ] Watch `Build and Deploy to ECS` workflow
  - [ ] Verify all steps complete successfully:
    - [ ] Checkout code
    - [ ] Configure AWS credentials
    - [ ] Login to ECR
    - [ ] Build Docker image
    - [ ] Push to ECR
    - [ ] Update task definition
    - [ ] Deploy to ECS

- [ ] **Monitor ECS Deployment**
  - [ ] Go to ECS console (ap-southeast-1)
  - [ ] Select cluster `default`
  - [ ] Select service `howmun-test`
  - [ ] Verify task is running (green)
  - [ ] Check desired count = 1, running = 1
  - [ ] Wait for health check to pass

- [ ] **Verify Application Running**
  - [ ] Get service endpoint from ECS console
  - [ ] Test health endpoint: `curl http://<endpoint>/health`
  - [ ] Test application: open in browser
  - [ ] Check CloudWatch logs: `aws logs tail /ecs/howmun-test --follow`

## Post-Deployment

- [ ] **Verify Logs**
  - [ ] Check CloudWatch logs for any errors
  - [ ] Verify migrations ran successfully (if enabled)
  - [ ] Check Laravel logs for warnings

- [ ] **Test Application**
  - [ ] Navigate main pages
  - [ ] Test database connectivity
  - [ ] Test file uploads/downloads (if applicable)
  - [ ] Test API endpoints (if applicable)

- [ ] **Monitoring Setup** (Optional but Recommended)
  - [ ] Set up CloudWatch alarms for:
    - [ ] Health check failures
    - [ ] CPU utilization
    - [ ] Memory utilization
    - [ ] Error logs
  - [ ] Set up SNS notifications
  - [ ] Create dashboard for monitoring

- [ ] **Documentation**
  - [ ] Update team with deployment endpoint
  - [ ] Document any custom configurations
  - [ ] Add links to CloudWatch dashboards
  - [ ] Document the deployment process

## Ongoing Maintenance

- [ ] **Regular Tasks**
  - [ ] Monitor CloudWatch logs regularly
  - [ ] Check health checks are passing
  - [ ] Review error logs
  - [ ] Update dependencies periodically
  - [ ] Backup database regularly

- [ ] **Scaling** (When Needed)
  - [ ] Increase CPU/memory in `docker/ecs-task-definition.json`
  - [ ] Adjust PHP-FPM workers in `docker/php/php-fpm.conf`
  - [ ] Use ECS service auto-scaling

- [ ] **Updates**
  - [ ] For code changes: push to main (auto-deploys)
  - [ ] For .env changes: update Parameter Store and restart service
  - [ ] For Dockerfile changes: verify builds locally first

## Troubleshooting

If deployment fails, check in this order:

1. [ ] **GitHub Actions Logs**
   - [ ] Go to Actions tab
   - [ ] Click failed run
   - [ ] Check error messages

2. [ ] **AWS Permissions**
   - [ ] Verify GitHub secrets are set
   - [ ] Verify IAM role exists and has permissions
   - [ ] Verify OIDC trust policy is correct

3. [ ] **Docker Build**
   - [ ] Build locally: `docker build -f Dockerfile.prod .`
   - [ ] Check for missing PHP extensions
   - [ ] Verify Composer/npm dependencies

4. [ ] **ECS Deployment**
   - [ ] Check CloudWatch logs: `aws logs tail /ecs/howmun-test --follow`
   - [ ] Check task status: `aws ecs describe-tasks --cluster default --tasks <task-arn>`
   - [ ] Check health check: `docker-compose logs app-prod | grep health`

5. [ ] **Application Issues**
   - [ ] Check `/health` endpoint exists
   - [ ] Verify nginx config is correct
   - [ ] Check PHP-FPM is running
   - [ ] Verify database connectivity

## Useful Commands

```bash
# View deployment logs
make prod-logs

# View AWS logs
aws logs tail /ecs/howmun-test --follow --region ap-southeast-1

# Check service status
aws ecs describe-services --cluster default --services howmun-test --region ap-southeast-1

# Force new deployment
aws ecs update-service --cluster default --service howmun-test --force-new-deployment --region ap-southeast-1

# View health status
curl http://<service-endpoint>/health

# List Docker images
docker image ls

# Clean up docker
docker system prune -f
```

## Support Resources

- **Documentation**: See `PRODUCTION.md` for troubleshooting
- **GitHub Actions**: See `.github/GITHUB_ACTIONS_SETUP.md`
- **AWS Setup**: Run `make aws-setup` with `--help`
- **Local Testing**: Use `docker-compose up app-prod` for debugging

---

✅ **Once all checkboxes are complete, your application is successfully deployed to AWS ECS!**

Next: Monitor logs regularly and keep dependencies updated.
