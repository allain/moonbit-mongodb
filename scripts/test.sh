#!/bin/bash
# Run tests with a temporary MongoDB container
#
# Usage: ./scripts/test.sh [moon test options]
# Example: ./scripts/test.sh --target native
#          ./scripts/test.sh --target native --update

set -e

CONTAINER_NAME="mongodb-test-$$"

# Start MongoDB container
echo "Starting MongoDB container..."
docker run -d --name "$CONTAINER_NAME" -p 27017:27017 mongo:7 > /dev/null

# Ensure cleanup on exit
cleanup() {
    echo "Stopping MongoDB container..."
    docker rm -f "$CONTAINER_NAME" > /dev/null 2>&1 || true
}
trap cleanup EXIT

# Wait for MongoDB to be ready
echo "Waiting for MongoDB to be ready..."
for i in {1..30}; do
    if docker exec "$CONTAINER_NAME" mongosh --eval "db.runCommand('ping').ok" --quiet > /dev/null 2>&1; then
        echo "MongoDB is ready"
        break
    fi
    if [ $i -eq 30 ]; then
        echo "MongoDB failed to start"
        exit 1
    fi
    sleep 1
done

# Run tests
echo "Running tests..."
moon test --target native "$@"
