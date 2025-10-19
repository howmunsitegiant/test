#!/bin/bash

set -e

echo "Starting Laravel Production Container Initialization..."

cd /var/www/html

# Fetch .env from AWS Parameter Store if running on ECS
if [ "$FETCH_ENV_FROM_AWS" = "true" ]; then
    echo "Fetching .env from AWS Parameter Store..."
    
    PARAM_NAME="${AWS_PARAM_NAME:-/howmun-test}"
    
    # Get parameter value from AWS Systems Manager Parameter Store
    aws ssm get-parameter \
        --name "$PARAM_NAME" \
        --query 'Parameter.Value' \
        --output text \
        --region "$AWS_REGION" > .env
    
    if [ $? -eq 0 ]; then
        echo ".env successfully fetched from Parameter Store"
    else
        echo "Failed to fetch .env from Parameter Store"
        exit 1
    fi
fi

# Verify .env exists
if [ ! -f ".env" ]; then
    echo "Warning: .env file not found. Creating from .env.example..."
    if [ -f ".env.example" ]; then
        cp .env.example .env
    else
        echo "Error: Neither .env nor .env.example found"
        exit 1
    fi
fi

# Generate application key if not already set
if ! grep -q "^APP_KEY=" .env || [ -z "$(grep '^APP_KEY=' .env | cut -d= -f2)" ]; then
    echo "Generating application key..."
    php artisan key:generate
fi

# Run migrations if needed
if [ "$RUN_MIGRATIONS" = "true" ]; then
    echo "Running database migrations..."
    php artisan migrate --force
fi

# Cache optimization
echo "Optimizing Laravel cache..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Set proper permissions
echo "Setting permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod -R 775 storage bootstrap/cache

echo "Container initialization complete!"

# Execute the main command
exec "$@"
