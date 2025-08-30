#!/usr/bin/env bash
set -euo pipefail

GROUP="${1:-spark-streaming-demo}"

echo "Describing consumer group '$GROUP'..."
docker exec broker1 kafka-consumer-groups --bootstrap-server broker1:9092 --describe --group "$GROUP" || true
