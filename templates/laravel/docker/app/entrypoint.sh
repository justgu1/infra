#!/bin/sh
set -e

if [ "$CONTAINER_ROLE" = "app" ] || [ -z "$CONTAINER_ROLE" ]; then
    echo "Running migrations..."
    php artisan migrate --force

    echo "Caching config..."
    php artisan config:cache
    php artisan route:cache
    php artisan view:cache

    echo "Starting Octane (Swoole)..."
    exec php artisan octane:start \
        --server=swoole \
        --host=0.0.0.0 \
        --port=8000 \
        --workers=${OCTANE_WORKERS:-auto} \
        --task-workers=${OCTANE_TASK_WORKERS:-auto} \
        --max-requests=${OCTANE_MAX_REQUESTS:-500}

elif [ "$CONTAINER_ROLE" = "queue" ]; then
    echo "Starting queue worker..."
    exec php artisan queue:work \
        --sleep=3 \
        --tries=3 \
        --max-time=3600

elif [ "$CONTAINER_ROLE" = "scheduler" ]; then
    echo "Starting scheduler..."
    exec php artisan schedule:work

else
    echo "Unknown CONTAINER_ROLE: $CONTAINER_ROLE"
    exit 1
fi