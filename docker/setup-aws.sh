#!/bin/bash

# AWS Setup Script for Laravel ECS Deployment
# This script sets up all necessary AWS resources for deploying the Laravel app

set -e

# Configuration
AWS_REGION="ap-southeast-1"
AWS_ACCOUNT_ID="${1:-794036769283}"
APP_NAME="howmun-test"
PARAM_NAME="/howmun-test"

echo "=========================================="
echo "AWS Setup Script for Laravel ECS"
echo "=========================================="
echo "AWS Region: $AWS_REGION"
echo "AWS Account: $AWS_ACCOUNT_ID"
echo "App Name: $APP_NAME"
echo ""

# Check AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI is not installed"
    exit 1
fi

# 1. Create ECR Repository
echo "1. Creating ECR Repository..."
aws ecr create-repository \
    --repository-name "$APP_NAME" \
    --region "$AWS_REGION" 2>/dev/null || echo "   Repository already exists"

ECR_URI="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME"
echo "   ✓ ECR Repository: $ECR_URI"

# 2. Create IAM Role for ECS Tasks
echo ""
echo "2. Creating IAM Role for ECS Tasks..."

# Create trust policy
cat > /tmp/trust-policy.json << 'EOF'
{
  "Version": "2012-10-17",
  "Statement": [{
    "Effect": "Allow",
    "Principal": {
      "Service": "ecs-tasks.amazonaws.com"
    },
    "Action": "sts:AssumeRole"
  }]
}
EOF

# Create role
aws iam create-role \
    --role-name "$APP_NAME-task-role" \
    --assume-role-policy-document file:///tmp/trust-policy.json 2>/dev/null || echo "   Role already exists"

# Attach policy
aws iam put-role-policy \
    --role-name "$APP_NAME-task-role" \
    --policy-name "$APP_NAME-policy" \
    --policy-document file://docker/iam-policy.json

echo "   ✓ IAM Role: $APP_NAME-task-role"

# 3. Store .env in Parameter Store
echo ""
echo "3. Storing .env in AWS Parameter Store..."

if [ ! -f ".env" ]; then
    echo "   Error: .env file not found"
    exit 1
fi

ENV_CONTENT=$(cat .env)

aws ssm put-parameter \
    --name "$PARAM_NAME" \
    --type "SecureString" \
    --value "$ENV_CONTENT" \
    --region "$AWS_REGION" \
    --overwrite 2>/dev/null || true

echo "   ✓ Parameter stored: $PARAM_NAME"

# 4. Create CloudWatch Log Group
echo ""
echo "4. Creating CloudWatch Log Group..."

aws logs create-log-group \
    --log-group-name "/ecs/$APP_NAME" \
    --region "$AWS_REGION" 2>/dev/null || echo "   Log group already exists"

echo "   ✓ Log Group: /ecs/$APP_NAME"

# 5. Create ECS Cluster (if doesn't exist)
echo ""
echo "5. Checking/Creating ECS Cluster..."

CLUSTER_EXISTS=$(aws ecs describe-clusters \
    --clusters "default" \
    --region "$AWS_REGION" \
    --query 'clusters[0].clusterName' \
    --output text 2>/dev/null || echo "")

if [ "$CLUSTER_EXISTS" != "default" ]; then
    aws ecs create-cluster \
        --cluster-name "default" \
        --region "$AWS_REGION"
    echo "   ✓ ECS Cluster created: default"
else
    echo "   ✓ ECS Cluster exists: default"
fi

# 6. GitHub Actions Secrets
echo ""
echo "=========================================="
echo "GitHub Actions Secrets Setup"
echo "=========================================="
echo "Add these secrets to your GitHub repository:"
echo ""
echo "Name: AWS_ACCOUNT_ID"
echo "Value: $AWS_ACCOUNT_ID"
echo ""
echo "Name: AWS_ROLE_TO_ASSUME"
echo "Value: arn:aws:iam::$AWS_ACCOUNT_ID:role/github-actions-role"
echo ""

# 7. Summary
echo ""
echo "=========================================="
echo "Setup Complete!"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Create 'github-actions-role' IAM role with permissions to:"
echo "   - Push to ECR ($ECR_URI)"
echo "   - Update ECS service"
echo ""
echo "2. Add GitHub Actions secrets to your repository"
echo ""
echo "3. Update docker/ecs-task-definition.json with:"
echo "   - Replace ACCOUNT_ID with: $AWS_ACCOUNT_ID"
echo ""
echo "4. Push to main branch to trigger deployment"
echo ""

# Cleanup
rm -f /tmp/trust-policy.json
