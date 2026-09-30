#!/usr/bin/env bash
set -e
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT="${SRC}/out"
mkdir -p "${OUTPUT}"

declare -a extra_args=("--build-arg" "BASE_IMAGE=debian:forky")

docker buildx build "${extra_args[@]}" --output "type=local,dest=${OUTPUT}" --progress=plain  -t kodi:gbm -f Dockerfile.kodi.v4l2requests .
echo "Done!"
ls -laht "${OUTPUT}"

# containerized-kodi stage; that actually produces a container, not an output file
docker buildx build "${extra_args[@]}" --target "containerized-kodi" --progress=plain  -t kodi:gbm-container -f Dockerfile.kodi.v4l2requests .
