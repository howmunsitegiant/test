# GitHub Actions Setup Guide

This guide explains how to set up GitHub Actions for automated Docker builds and ECS deployments.

## Prerequisites

1. AWS Account with appropriate permissions
2. GitHub repository with GitHub Actions enabled
3. This Laravel application pushed to GitHub

## Step 1: Create IAM Role for GitHub Actions

Create an IAM role that GitHub Actions can assume (using OpenID Connect):

### Option A: Using AWS Console

1. Go to IAM → Roles → Create Role
2. Select "Web Identity" as trust entity
3. Provider: `token.actions.githubusercontent.com`
4. Audience: `sts.amazonaws.com`
5. Subject: `repo:howmunsitegiant/test:ref:refs/heads/main`
6. Attach policies (see below)
7. Name it: `github-actions-role`

### Option B: Using AWS CLI

```bash
# Create trust policy
cat > trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Federated": "arn:aws:iam::794036769283:oidc-provider/token.actions.githubusercontent.com"
    },
    "Action": "sts:AssumeRoleWithWebIdentity",
    "Condition": {
      "StringEquals": {
        "token.actions.githubusercontent.com:aud": "sts.amazonaws.com",
        "token.actions.githubusercontent.com:sub": "repo:howmunsitegiant/test:ref:refs/heads/main"
      }
    }
  }]
}
EOF

# Create role
aws iam create-role \
  --role-name github-actions-role \
  --assume-role-policy-document file://trust-policy.json \
  --region ap-southeast-1
```

## Step 2: Attach Permissions to the Role

Create and attach this policy:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:BatchGetImage",
        "ecr:GetDownloadUrlForLayer",
        "ecr:PutImage",
        "ecr:InitiateLayerUpload",
        "ecr:UploadLayerPart",
        "ecr:CompleteLayerUpload"
      ],
      "Resource": "arn:aws:ecr:ap-southeast-1:794036769283:repository/howmun-test"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecs:DescribeServices",
        "ecs:DescribeTaskDefinition",
        "ecs:DescribeTasks",
        "ecs:ListTasks",
        "ecs:RegisterTaskDefinition",
        "ecs:UpdateService"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::794036769283:role/ecsTaskExecutionRole",
        "arn:aws:iam::794036769283:role/howmun-test-task-role"
      ]
    }
  ]
}
EOF

# Attach policy
aws iam put-role-policy \
  --role-name github-actions-role \
  --policy-name github-actions-policy \
  --policy-document file://policy.json
```

## Step 3: Add GitHub Secrets

Go to your GitHub repository → Settings → Secrets and variables → Actions

Add these secrets:

| Secret Name | Value |
|---|---|
| `AWS_ACCOUNT_ID` | `794036769283` |
| `AWS_ROLE_TO_ASSUME` | `arn:aws:iam::794036769283:role/github-actions-role` |

## Step 4: Update Task Definition

Edit `docker/ecs-task-definition.json` and replace:
- `ACCOUNT_ID` → `794036769283`

## Step 5: Test the Workflow

1. Push a commit to `main` branch
2. Go to GitHub → Actions tab
3. Watch the build-deploy workflow
4. Check CloudWatch logs if needed

## Workflow Triggers

The workflow runs on:
- **Automatic**: Push to `main` branch
- **Manual**: Via GitHub Actions "Run workflow" button

## Debugging

### Check Workflow Logs
- GitHub Actions tab → Click on failed run → View logs

### Check ECS Deployment
```bash
# View service status
aws ecs describe-services \
  --cluster default \
  --services howmun-test \
  --region ap-southeast-1

# View task logs
aws logs tail /ecs/howmun-test --follow --region ap-southeast-1
```

### Common Issues

**1. Role Assumption Fails**
- Verify trust policy matches GitHub repo (OWNER/REPO/main)
- Check that OIDC provider exists in IAM

**2. ECR Push Fails**
- Verify ECR repository exists: `howmun-test`
- Check IAM policy allows ECR actions
- Run `aws sts get-caller-identity` to verify role assumption

**3. ECS Update Fails**
- Verify task role ARN is correct in task definition
- Check that ECS cluster and service exist
- Verify security groups allow health check on port 80

**4. Health Check Fails**
- Ensure `/health` route exists in `routes/web.php`
- Check Nginx logs: `docker-compose logs app-prod`
- Verify port 80 is accessible

## Manual Deployment Alternative

If automated deployment fails, deploy manually:

```bash
# Build image
docker build -f Dockerfile.prod -t ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/howmun-test:latest .

# Push to ECR
aws ecr get-login-password --region ap-southeast-1 | docker login --username AWS --password-stdin ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com
docker push ACCOUNT_ID.dkr.ecr.ap-southeast-1.amazonaws.com/howmun-test:latest

# Update service
aws ecs update-service \
  --cluster default \
  --service howmun-test \
  --force-new-deployment \
  --region ap-southeast-1
```
