ARG BASE_IMAGE="debian:bookworm"
FROM ${BASE_IMAGE} as build

ARG OS_ARCH="arm64"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update && apt-get -y dist-upgrade && apt-get -y install git bash wget curl build-essential devscripts debhelper pkg-config cmake meson tree colorized-logs
SHELL ["/bin/bash", "-e", "-c"]


# Build stuff from source
FROM build as packager


# RKMPP
WORKDIR /src
RUN git -c advice.detachedHead=false clone -b jellyfin-mpp --depth=1 https://github.com/nyanmisaka/mpp.git /src/rkmpp
WORKDIR /src/rkmpp/rkmpp_build
RUN pipetty cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DBUILD_TEST=OFF ..
RUN pipetty make -j$(nproc)
RUN pipetty make install

# RKRGA
WORKDIR /src
RUN git -c advice.detachedHead=false clone -b jellyfin-rga --depth=1 https://github.com/nyanmisaka/rk-mirrors.git rkrga
RUN pipetty meson setup rkrga rkrga_build \
    --prefix=/usr/local \
    --libdir=lib \
    --buildtype=release \
    --default-library=shared \
    -Dcpp_args=-fpermissive \
    -Dlibdrm=false \
    -Dlibrga_demo=false
RUN pipetty meson configure rkrga_build
RUN pipetty ninja -C rkrga_build install


# Dependencies for ffmpeg
RUN apt-get -y install libdrm-dev


# ffmpeg, with rkxxx stuff. Nyanmisaka's fork, full of boogie goodness.
WORKDIR /src
RUN git -c advice.detachedHead=false clone --depth=1 https://github.com/nyanmisaka/ffmpeg-rockchip.git ffmpeg
WORKDIR /src/ffmpeg
RUN pipetty ./configure --prefix=/usr/local --enable-gpl --enable-version3 --enable-libdrm --enable-rkmpp --enable-rkrga
RUN pipetty make -j $(nproc)
RUN pipetty make install

# Libdisplay-info, a hard dependency for kodi GBM.
RUN apt-get -y install hwdata # it is actually a build-time dependency only
WORKDIR /src
RUN git -c advice.detachedHead=false clone https://gitlab.freedesktop.org/emersion/libdisplay-info.git
WORKDIR /src/libdisplay-info
RUN mkdir build && cd build && meson setup --prefix=/usr/local --buildtype=release .. && ninja && ninja install


# Generic Dependencies for kodi
RUN apt-get -y install debhelper autoconf automake autopoint gettext autotools-dev cmake curl default-jre doxygen gawk gcc gdc gperf  libtool lsb-release meson nasm ninja-build \
               python3-dev python3-pil python3-pip swig unzip uuid-dev zip 
    
RUN apt-get -y install libasound2-dev libass-dev libavahi-client-dev \
    libavahi-common-dev libbluetooth-dev libbluray-dev libbz2-dev libcdio-dev libcdio++-dev libp8-platform-dev libcrossguid-dev libcurl4-openssl-dev libcwiid-dev libdbus-1-dev libdrm-dev \
    libegl1-mesa-dev libenca-dev libexiv2-dev libflac-dev libfmt-dev libfontconfig-dev libfreetype6-dev libfribidi-dev libfstrcmp-dev libgcrypt-dev libgif-dev \
    libgles2-mesa-dev libgl1-mesa-dev libglu1-mesa-dev libgnutls28-dev libgpg-error-dev libgtest-dev libiso9660-dev libjpeg-dev liblcms2-dev libltdl-dev liblzo2-dev \
    libmicrohttpd-dev libnfs-dev libogg-dev libpcre2-dev libplist-dev libpng-dev libpulse-dev libshairplay-dev libsmbclient-dev libspdlog-dev libsqlite3-dev \
    libssl-dev libtag1-dev libtiff5-dev libtinyxml-dev libtinyxml2-dev libudev-dev libunistring-dev libvorbis-dev libxmu-dev libxrandr-dev \
    libxslt1-dev libxt-dev rapidjson-dev zlib1g-dev # Removed: libva-dev libvdpau-dev 

# Kodi GBM dependencies; also CEC and  MariaDB (not Mysql) dependencies.
RUN apt-get -y install libgbm-dev libinput-dev libxkbcommon-dev libcec-dev libmariadb-dev


# kodi. This is a big one. we grab boogie's patches and cherry pick them on the master branch.
WORKDIR /src
RUN git -c advice.detachedHead=false clone https://github.com/xbmc/xbmc kodi
WORKDIR /src/kodi

# Pick boogie's patches. # Cherry pick the last 2 commits from boogie's branch.
RUN git config --global user.email "you@example.com" && git config --global user.name "Your Name"
RUN git remote add boogie https://github.com/hbiyik/xbmc.git
RUN git fetch boogie gbm_drm_dynamic_afbc_video_planes:gbm_drm_dynamic_afbc_video_planes
RUN git cherry-pick gbm_drm_dynamic_afbc_video_planes~2..gbm_drm_dynamic_afbc_video_planes
RUN git log -n 10

WORKDIR /src/kodi-build
RUN pipetty cmake ../kodi -DCMAKE_INSTALL_PREFIX=/usr/local -DCORE_PLATFORM_NAME=gbm -DAPP_RENDER_SYSTEM=gles -DENABLE_INTERNAL_FMT=ON -DENABLE_INTERNAL_FLATBUFFERS=ON
RUN pipetty cmake --build . -- -j$(nproc)
RUN pipetty make install

# Drop headers. We don't need them in the final package.
RUN rm -rfv /usr/local/include

### ------- packaging
WORKDIR /out/usr
RUN cp -pr /usr/local /out/usr/

# Prepare debian binary package
WORKDIR /pkg/src
ADD debian /pkg/src/debian
RUN cp -rp /out/* /pkg/src/
RUN echo "usr/*" > debian/kodi-rockchip-gbm.install

# Create the "Architecture: amd64" field in control
RUN echo "Architecture: ${OS_ARCH}" >> /pkg/src/debian/control
RUN cat /pkg/src/debian/control

# Create the Changelog, fake. The atrocities we do in dockerfiles.
ARG PACKAGE_VERSION="20240930"
RUN echo "kodi-rockchip-gbm (${PACKAGE_VERSION}) stable; urgency=medium" >> /pkg/src/debian/changelog
RUN echo "" >> /pkg/src/debian/changelog
RUN echo "  * Not a real changelog. Sorry." >> /pkg/src/debian/changelog
RUN echo "" >> /pkg/src/debian/changelog
RUN echo " -- Ricardo Pardini <ricardo@pardini.net>  Wed, 15 Sep 2021 14:18:33 +0200" >> /pkg/src/debian/changelog
RUN cat /pkg/src/debian/changelog


# Build the package, don't sign it, don't lint it, compress fast with xz
WORKDIR /pkg/src
RUN pipetty debuild --no-lintian --build=binary -us -uc -Zxz -z1 
RUN file /pkg/*.deb

# Show package info
RUN dpkg-deb -I /pkg/*.deb || true
RUN dpkg-deb -f /pkg/*.deb || true

# Install it to make sure it works
RUN dpkg -i /pkg/*.deb
# RUN dpkg -L kodi-rockchip-gbm

RUN lsb_release -a

# Now prepare the real output: the .deb for this release and arch.
WORKDIR /artifacts
RUN cp -v /pkg/*.deb kodi-rockchip-gbm_${OS_ARCH}_$(lsb_release -c -s).deb

# Final stage is just alpine so we can start a fake container just to get at its contents using docker in GHA
FROM alpine:3
COPY --from=packager /artifacts/* /out/

