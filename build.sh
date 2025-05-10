#!/usr/bin/env bash

SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${SRC}/out"
mkdir -p "${OUTPUT}"
docker buildx build --output "type=local,dest=${OUTPUT}" --progress=plain -t kodi:gbm .
echo "Done!"
ls -laht "${OUTPUT}"