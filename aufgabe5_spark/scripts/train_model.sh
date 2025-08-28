#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR/.."

# If you don't have system Spark, install PySpark first:
#   python -m pip install -r spark/requirements.txt
spark-submit spark/train_kmeans.py
