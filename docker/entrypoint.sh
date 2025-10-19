#!/bin/bash

set -e

echo "Starting Laravel Docker Container Initialization..."

# Navigate to application directory
cd /var/www/html

# Install PHP dependencies if vendor directory doesn't exist
if [ ! -d "vendor" ]; then
    echo "Installing Composer dependencies..."
    composer install --optimize-autoloader --no-dev
else
    echo "Composer dependencies already installed"
fi

# Copy .env file if it doesn't exist
if [ ! -f ".env" ]; then
    echo "Creating .env file from .env.example..."
    cp .env.example .env || echo "Note: .env.example not found, skipping"
    php artisan key:generate
fi

# Run migrations
echo "Running database migrations..."
php artisan migrate --force || true

# Cache configuration and routes for better performance
echo "Caching configuration and routes..."
php artisan config:cache
php artisan route:cache
php artisan view:cache

# Set proper permissions
echo "Setting permissions..."
chown -R www-data:www-data /var/www/html
chmod -R 755 /var/www/html
chmod -R 775 storage bootstrap/cache

echo "Laravel setup complete!"

# Execute the main command
exec "$@"
