#!/usr/bin/env bash
set -euo pipefail

TOPIC_NAME="${1:-events}"
PARTITIONS="${2:-6}"
REPL="${3:-3}"

echo "Creating topic '$TOPIC_NAME' with $PARTITIONS partitions and RF=$REPL..."
docker exec broker1 kafka-topics --create --if-not-exists --topic "$TOPIC_NAME"   --partitions "$PARTITIONS" --replication-factor "$REPL" --bootstrap-server broker1:9092

echo "Listing topics:"
docker exec broker1 kafka-topics --list --bootstrap-server broker1:9092

echo "Describing topic:"
docker exec broker1 kafka-topics --describe --topic "$TOPIC_NAME" --bootstrap-server broker1:9092
