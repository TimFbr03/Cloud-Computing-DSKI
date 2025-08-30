#!/usr/bin/env bash
# Runs the streaming job locally. Assumes either:
# 1) You installed Spark via Homebrew (spark-submit on PATH), or
# 2) You installed PySpark via pip (pyspark provides a bundled spark-submit)
#
# If 1) fails, try: python -m pip install -r spark/requirements.txt

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

PKG="org.apache.spark:spark-sql-kafka-0-10_2.12:3.5.1"

spark-submit --packages "$PKG"   --conf spark.sql.shuffle.partitions=6   --conf spark.default.parallelism=6   spark/stream_app.py
