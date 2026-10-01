#!/usr/bin/env bash
# Local build for kodi-rockchip-gbm; see the GHA workflow for the full CI matrix.
# Everything is controlled via environment variables, e.g.:
#   FLAVOR=v4l2requests DISTRO=forky ./build.sh
#   FLAVOR=rkmpp BUILD_CONTAINER=no ./build.sh
#   EXPORT_DEB=no CONTAINER_TAG=ghcr.io/me/kodi:test ./build.sh
set -euo pipefail
SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SRC}"

FLAVOR="${FLAVOR:-rkmpp}"                   # rkmpp (vendor kernel) | v4l2requests (mainline kernel)
DISTRO="${DISTRO:-trixie}"                  # trixie | forky | resolute
BUILD_DEB="${BUILD_DEB:-yes}"               # build the .deb (packager stage)
EXPORT_DEB="${EXPORT_DEB:-yes}"             # yes: write the .deb to OUTPUT; no: load the .deb-only image as DEB_TAG
BUILD_CONTAINER="${BUILD_CONTAINER:-yes}"   # also build the runnable containerized-kodi image
OUTPUT="${OUTPUT:-${SRC}/out}"              # where the .deb lands when EXPORT_DEB=yes
DEB_TAG="${DEB_TAG:-kodi-rockchip-gbm:${DISTRO}-${FLAVOR}-deb}"
CONTAINER_TAG="${CONTAINER_TAG:-kodi-rockchip-gbm:${DISTRO}-${FLAVOR}}"
PACKAGE_VERSION="${PACKAGE_VERSION:-}"      # empty: Dockerfile default (keeps the build cache warm)
BUILD_CMD="${BUILD_CMD:-docker buildx build}"
SUMMARY_DELAY="${SUMMARY_DELAY:-5}"         # seconds to show the summary before building (ENTER skips); 0 to skip

die() { echo "ERROR: $*" >&2; exit 1; }

is_bool() { [[ "$1" == "yes" || "$1" == "no" ]]; }
for var in BUILD_DEB EXPORT_DEB BUILD_CONTAINER; do
	is_bool "${!var}" || die "${var} must be 'yes' or 'no', got '${!var}'"
done

case "${FLAVOR}" in
	rkmpp | v4l2requests) DOCKERFILE="Dockerfile.kodi.${FLAVOR}" ;;
	*) die "FLAVOR must be 'rkmpp' or 'v4l2requests', got '${FLAVOR}'" ;;
esac

case "${DISTRO}" in
	trixie | forky) BASE_IMAGE="${BASE_IMAGE:-debian:${DISTRO}}" ;;
	resolute) BASE_IMAGE="${BASE_IMAGE:-ubuntu:${DISTRO}}" ;;
	*) die "DISTRO must be 'trixie', 'forky' or 'resolute', got '${DISTRO}'" ;;
esac

[[ "${BUILD_DEB}" == "yes" || "${BUILD_CONTAINER}" == "yes" ]] || die "nothing to do: both BUILD_DEB and BUILD_CONTAINER are 'no'"

declare -a build_args=("--build-arg" "BASE_IMAGE=${BASE_IMAGE}")
[[ -n "${PACKAGE_VERSION}" ]] && build_args+=("--build-arg" "PACKAGE_VERSION=${PACKAGE_VERSION}")

# Plan the operations, so the summary shows exactly what will run.
declare -a ops=()
if [[ "${BUILD_DEB}" == "yes" ]]; then
	if [[ "${EXPORT_DEB}" == "yes" ]]; then
		ops+=(".deb: build, export to ${OUTPUT}")
	else
		ops+=(".deb: build, load as image ${DEB_TAG} (not exported)")
	fi
fi
[[ "${BUILD_CONTAINER}" == "yes" ]] && ops+=("container: build containerized-kodi, load as ${CONTAINER_TAG}")

echo "================ kodi-rockchip-gbm build ================"
printf '  %-16s %s\n' \
	FLAVOR "${FLAVOR}" \
	DISTRO "${DISTRO}" \
	BASE_IMAGE "${BASE_IMAGE}" \
	DOCKERFILE "${DOCKERFILE}" \
	BUILD_DEB "${BUILD_DEB}" \
	EXPORT_DEB "${EXPORT_DEB}" \
	OUTPUT "${OUTPUT}" \
	DEB_TAG "${DEB_TAG}" \
	BUILD_CONTAINER "${BUILD_CONTAINER}" \
	CONTAINER_TAG "${CONTAINER_TAG}" \
	PACKAGE_VERSION "${PACKAGE_VERSION:-(Dockerfile default)}" \
	BUILD_CMD "${BUILD_CMD}"
echo "  Operations:"
for i in "${!ops[@]}"; do echo "    $((i + 1)). ${ops[$i]}"; done
echo "========================================================="
if [[ "${SUMMARY_DELAY}" -gt 0 ]]; then
	if [[ -t 0 ]]; then # interactive: ENTER skips the wait
		echo "Starting in ${SUMMARY_DELAY}s; ENTER to start now, Ctrl-C to abort..."
		read -r -s -t "${SUMMARY_DELAY}" _ || true # times out non-zero; that's fine
	else
		echo "Starting in ${SUMMARY_DELAY}s; Ctrl-C to abort..."
		sleep "${SUMMARY_DELAY}"
	fi
fi

read -r -a build_cmd <<< "${BUILD_CMD}"

if [[ "${BUILD_DEB}" == "yes" ]]; then
	if [[ "${EXPORT_DEB}" == "yes" ]]; then
		mkdir -p "${OUTPUT}"
		"${build_cmd[@]}" "${build_args[@]}" --progress=plain --output "type=local,dest=${OUTPUT}" -f "${DOCKERFILE}" .
		echo "Done: .deb exported to ${OUTPUT}"
		ls -laht "${OUTPUT}"
	else
		"${build_cmd[@]}" "${build_args[@]}" --progress=plain --load -t "${DEB_TAG}" -f "${DOCKERFILE}" .
		echo "Done: .deb image loaded as ${DEB_TAG}"
	fi
fi

# containerized-kodi stage; that actually produces a runnable container, not an output file
if [[ "${BUILD_CONTAINER}" == "yes" ]]; then
	"${build_cmd[@]}" "${build_args[@]}" --progress=plain --target "containerized-kodi" --load -t "${CONTAINER_TAG}" -f "${DOCKERFILE}" .
	echo "Done: container loaded as ${CONTAINER_TAG}"
fi
