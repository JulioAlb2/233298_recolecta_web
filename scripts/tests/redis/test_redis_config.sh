#!/bin/bash
# Test script for Redis configuration
set -e

echo "Starting Redis configuration test..."

# Ensure we run from project root so the relative path resolves correctly
cd "$(dirname "$0")/../../.." || exit 1

CONFIG_FILE="docker/redis/redis.conf"

# Check if the configuration file exists

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: Redis configuration file '$CONFIG_FILE' does not exist."
    exit 1
fi

# Check key params in the config file
grep -q "appendonly yes" "$CONFIG_FILE" || { echo "Error: 'appendonly yes' not found in config."; exit 1; }
grep -q "appendfsync everysec" "$CONFIG_FILE" || { echo "Error: 'appendfsync everysec' not found in config."; exit 1; }
grep -q "requirepass" "$CONFIG_FILE" || { echo "Error: 'requirepass' not found in config."; exit 1; }
grep -q "maxmemory" "$CONFIG_FILE" || { echo "Error: 'maxmemory' not found in config."; exit 1; }

echo "Redis configuration test passed successfully!"

exit 0