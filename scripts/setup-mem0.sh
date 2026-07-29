#!/bin/bash
# setup-mem0.sh — Pre-initialize the mem0 Qdrant storage with correct embedding dimensions.
# Run once after installing pip packages. Idempotent — safe to re-run.
set -euo pipefail

HERMES_HOME="${HERMES_HOME:-$HOME/.hermes}"
CONFIG_FILE="$HERMES_HOME/mem0.json"
QDRANT_PATH="$HERMES_HOME/mem0_qdrant"
HERMES_VENV="$HOME/.hermes/hermes-agent/venv/bin/python3"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "No mem0.json found at $CONFIG_FILE — nothing to set up."
  exit 0
fi

# Use Hermes venv Python to pick up qdrant-client and mem0ai packages
PYTHON_BIN="$HERMES_VENV"
if [ ! -x "$PYTHON_BIN" ]; then
  PYTHON_BIN="python3"
fi

echo "Setting up mem0 Qdrant storage..."
"$PYTHON_BIN" -c "
import json
from pathlib import Path
from qdrant_client import QdrantClient
from qdrant_client.http import models

config_path = Path('$CONFIG_FILE')
with open(config_path) as f:
    cfg = json.load(f)

dims = cfg.get('oss', {}).get('embedder', {}).get('config', {}).get('embedding_dims', 768)
collection = cfg.get('oss', {}).get('vector_store', {}).get('config', {}).get('collection_name', 'mem0')
qdrant_path = Path('$QDRANT_PATH')

client = QdrantClient(path=str(qdrant_path))

if client.collection_exists(collection):
    info = client.get_collection(collection)
    vectors = info.config.params.vectors
    if isinstance(vectors, dict):
        current_dims = next(iter(vectors.values())).size if vectors else None
    else:
        current_dims = getattr(vectors, 'size', None)
    if current_dims == dims:
        print(f'✓ Collection {collection} exists with {dims} dims')
    else:
        client.delete_collection(collection)
        print(f'Recreated collection (was {current_dims}d, now {dims}d)')
        client.create_collection(collection_name=collection, vectors_config=models.VectorParams(size=dims, distance=models.Distance.COSINE))
else:
    client.create_collection(collection_name=collection, vectors_config=models.VectorParams(size=dims, distance=models.Distance.COSINE))
    print(f'✓ Created collection {collection} with {dims} dims')
"

echo "Done."
