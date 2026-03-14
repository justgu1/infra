FROM php:8.4-cli

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git curl zip unzip \
    libpng-dev libonig-dev libxml2-dev libzip-dev libpq-dev \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install PHP extensions
RUN docker-php-ext-install \
    pdo pdo_pgsql pdo_mysql \
    mbstring exif pcntl bcmath gd zip dom opcache

# Install Swoole for Laravel Octane
RUN pecl install swoole \
    && docker-php-ext-enable swoole

# Install Composer
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer

# Create app user
RUN useradd -u 1000 -ms /bin/bash appuser

WORKDIR /var/www/html

# Copy application files
COPY --chown=appuser:appuser . .

# Install PHP dependencies (no dev)
RUN composer install --no-dev --optimize-autoloader --no-interaction

# Set permissions
RUN chown -R appuser:appuser /var/www/html/storage /var/www/html/bootstrap/cache

USER appuser

COPY --chown=appuser:appuser docker/app/entrypoint.sh /entrypoint.sh
ENTRYPOINT ["/entrypoint.sh"]