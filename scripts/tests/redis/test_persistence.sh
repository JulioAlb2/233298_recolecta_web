#!/bin/bash
set -e

echo "Starting Redis persistence test..."

# Source .env if available so REDIS_PASSWORD is set
if [ -f .env ]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

PASS="${REDIS_PASSWORD:-r3d1s_s3cur3_p4ss}"

# SET
docker exec -e REDISCLI_AUTH=$PASS redis_cache redis-cli SET test:persist "test-data" > /dev/null
echo "SET key 'test:persist' with value 'test-data'"

# BGSAVE
docker exec -e REDISCLI_AUTH=$PASS redis_cache redis-cli BGSAVE > /dev/null
sleep 2
echo "BGSAVE completed"

# Restart container to test persistence
docker restart redis_cache > /dev/null
sleep 3
echo "Container restarted"

# GET
VALUE=$(docker exec -e REDISCLI_AUTH=$PASS redis_cache redis-cli GET test:persist)
if [ "$VALUE" = "test-data" ]; then
  echo "Persistence verified: value retrieved successfully ($VALUE)"
  exit 0
else
  echo "Persistence failed: value not retrieved ($VALUE)"
  exit 1
fi