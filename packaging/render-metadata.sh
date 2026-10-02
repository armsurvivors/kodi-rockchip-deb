#!/usr/bin/env bash
# Renders the flavor/version-specific packaging metadata, in place, from the templates in the package source dir:
#  - debian/control: Architecture, flavor fields and the description
#  - debian/changelog: fake, single entry carrying the version
#  - Kodi's appliance.xml: build info, as a header comment
# Called from the Dockerfile; inputs come from the environment (the Dockerfile ARGs).
set -euo pipefail

PKG_SRC="${1:?usage: $0 <package source dir>}"
: "${FLAVOR:?}" "${OS_ARCH:?}" "${PACKAGE_VERSION:?}" "${KODI_BRANCH:?}" "${FFMPEG_BRANCH:?}" "${FFMPEG_ID:?}" "${DAV1D_BRANCH:?}"
SRC_DIR="${SRC_DIR:-/src}" # where the git clones live

CONTROL="${PKG_SRC}/debian/control"
CHANGELOG="${PKG_SRC}/debian/changelog"
APPLIANCE="${PKG_SRC}/usr/local/share/kodi/system/settings/appliance.xml"

rev() { git -C "${SRC_DIR}/$1" rev-parse --short=10 HEAD 2> /dev/null || echo "unknown"; }

DISTRO="$(lsb_release -c -s)"
DEB_VERSION="${PACKAGE_VERSION}-kodi-${KODI_BRANCH}-ffmpeg-${FFMPEG_ID}"
KODI_REV="$(rev kodi)"
FFMPEG_REV="$(rev ffmpeg)"

case "${FLAVOR}" in
	rkmpp)
		SYNOPSIS="Kodi GBM/GLES for Rockchip vendor kernels (rkmpp + rkrga hw decoding)"
		FFMPEG_NAME="ffmpeg-rockchip"
		EXTRA_COMPONENTS=", MPP @$(rev rkmpp), RGA @$(rev rkrga)"
		FLAVOR_PARAGRAPH="This is the rkmpp flavor, for Rockchip vendor/BSP kernels (Armbian 'vendor', 6.1-rkr). Hardware video decoding uses Rockchip MPP and RGA through nyanmisaka's ffmpeg-rockchip. It will NOT work on mainline kernels; use the v4l2requests flavor there."
		;;
	v4l2requests)
		SYNOPSIS="Kodi GBM/GLES for mainline kernels (V4L2 Request API hw decoding)"
		FFMPEG_NAME="FFmpeg"
		EXTRA_COMPONENTS=""
		FLAVOR_PARAGRAPH="This is the v4l2requests flavor, for mainline kernels (Armbian rockchip64 'edge'). Hardware video decoding uses the kernel's V4L2 stateless decoders (hantro, rkvdec, ...) through FFmpeg with LibreELEC's V4L2 Request API patches, plus the DRM PRIME deinterlace filter. It will NOT work on Rockchip vendor kernels; use the rkmpp flavor there."
		;;
	*)
		echo "ERROR: unknown FLAVOR '${FLAVOR}'" >&2
		exit 1
		;;
esac

BUILD_INFO="${FLAVOR} ${PACKAGE_VERSION} (${DISTRO}/${OS_ARCH})"
COMPONENTS="Kodi ${KODI_BRANCH} @${KODI_REV}, ${FFMPEG_NAME} ${FFMPEG_BRANCH} @${FFMPEG_REV}, dav1d ${DAV1D_BRANCH}${EXTRA_COMPONENTS}"

# Debian extended description: one space indent, paragraphs separated by " ."
desc_paragraph() { printf '%s\n' "$1" | fold -s -w 76 | sed -e 's/ *$//' -e 's/^/ /'; }
LONG_DESCRIPTION="$(
	desc_paragraph "Kodi media center, built from git for standalone GBM/KMS with GLES rendering, for Rockchip boards running Armbian."
	echo " ."
	desc_paragraph "${FLAVOR_PARAGRAPH}"
	echo " ."
	desc_paragraph "Bundles its own FFmpeg, dav1d and libdisplay-info plus the shadertoy add-ons, all under /usr/local (not proper FHS packaging). Ships the systemd units kodi (ALSA) and kodi-pulse (PulseAudio), and a Kodi appliance.xml defaulting to DRM PRIME hw acceleration with Direct-To-Plane rendering. Installing disables GDM3/SDDM/LightDM, as Kodi takes over KMS."
	echo " ."
	desc_paragraph "Built for ${DISTRO}/${OS_ARCH}: ${COMPONENTS}."
)"

xml_escape() {
	local s="$1"
	s="${s//&/&amp;}"
	s="${s//</&lt;}"
	s="${s//>/&gt;}"
	printf '%s' "${s}"
}

# usage: render <file> <placeholder> <value> [<placeholder> <value> ...]; literal replacement, in place.
render() {
	local file="$1" content
	shift
	content="$(< "${file}")"
	while [[ $# -gt 0 ]]; do
		content="${content//"$1"/"$2"}"
		shift 2
	done
	printf '%s\n' "${content}" > "${file}"
	if grep -nE '@[A-Z_]+@' "${file}"; then
		echo "ERROR: unrendered placeholders left in ${file}" >&2
		exit 1
	fi
}

render "${CONTROL}" \
	@ARCH@ "${OS_ARCH}" \
	@FLAVOR@ "${FLAVOR}" \
	@BUILD_INFO@ "${BUILD_INFO}" \
	@COMPONENTS@ "${COMPONENTS}" \
	@SYNOPSIS@ "${SYNOPSIS}" \
	@LONG_DESCRIPTION@ "${LONG_DESCRIPTION}"

render "${APPLIANCE}" \
	@BUILD_INFO@ "$(xml_escape "${BUILD_INFO}")" \
	@COMPONENTS@ "$(xml_escape "${COMPONENTS}")"

cat > "${CHANGELOG}" <<- CHANGELOG_ENTRY
	kodi-rockchip-gbm (${DEB_VERSION}) stable; urgency=medium

	  * Not a real changelog. Sorry.
	  * ${BUILD_INFO}: ${COMPONENTS}

	 -- Ricardo Pardini <ricardo@pardini.net>  $(date -R)
CHANGELOG_ENTRY

echo "Rendered metadata for ${BUILD_INFO}: ${COMPONENTS}"
