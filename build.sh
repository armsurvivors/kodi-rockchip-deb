#!/usr/bin/env bash
set -e
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${SRC}/out"
mkdir -p "${OUTPUT}"

declare -a extra_args=("--build-arg" "BASE_IMAGE=debian:trixie")

docker buildx build "${extra_args[@]}" --output "type=local,dest=${OUTPUT}" --progress=plain  -t kodi:gbm .
echo "Done!"
ls -laht "${OUTPUT}"

# containerized-kodi stage; that actually produces a container, not an output file
docker buildx build "${extra_args[@]}" --target "containerized-kodi" --progress=plain  -t kodi:gbm-container .
