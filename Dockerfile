# Warning to the reader. This produces a .deb package with stuff in /usr/local. If this scares you, stop reading.
# It is in fact, non-debian packaging. Probably fpm would be a better choice?
ARG BASE_IMAGE="ubuntu:jammy"
FROM ${BASE_IMAGE} AS packager

#### Dependencies. In batches; this is built under buildx and layers not published so we don't care about layer size.
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update && apt-get -y dist-upgrade && apt-get -y install git bash wget curl build-essential devscripts debhelper pkg-config cmake meson tree colorized-logs
# Dependencies for ffmpeg
RUN apt-get -y install libdrm-dev
# Deps for libdisplay-info
RUN apt-get -y install hwdata # it is actually a build-time dependency only
# Generic Dependencies for kodi
RUN apt-get -y install debhelper autoconf automake autopoint gettext autotools-dev cmake curl default-jre doxygen gawk gcc gdc gperf libtool lsb-release meson nasm ninja-build \
               python3-dev python3-pil python3-pip swig unzip uuid-dev zip 

RUN apt-get -y install libasound2-dev libass-dev libavahi-client-dev \
    libavahi-common-dev libbluetooth-dev libbluray-dev libbz2-dev libcdio-dev libcdio++-dev libp8-platform-dev libcrossguid-dev libcurl4-openssl-dev libcwiid-dev libdbus-1-dev  \
    libegl1-mesa-dev libenca-dev libexiv2-dev libflac-dev libfmt-dev libfontconfig-dev libfreetype6-dev libfribidi-dev libfstrcmp-dev libgcrypt-dev libgif-dev \
    libgles2-mesa-dev libgl1-mesa-dev libglu1-mesa-dev libgnutls28-dev libgpg-error-dev libgtest-dev libiso9660-dev libjpeg-dev liblcms2-dev libltdl-dev liblzo2-dev \
    libmicrohttpd-dev libnfs-dev libogg-dev libpcre2-dev libplist-dev libpng-dev libpulse-dev libshairplay-dev libsmbclient-dev libspdlog-dev libsqlite3-dev \
    libssl-dev libtag1-dev libtiff5-dev libtinyxml-dev libtinyxml2-dev libudev-dev libunistring-dev libvorbis-dev  \
    libxslt1-dev libxt-dev rapidjson-dev zlib1g-dev # Removed: libva-dev libvdpau-dev libxmu-dev libxrandr-dev libdrm-dev

# Kodi GBM dependencies; also CEC and  MariaDB (not Mysql) dependencies.
RUN apt-get -y install libgbm-dev libinput-dev libxkbcommon-dev libcec-dev libmariadb-dev

#### Git clones. Heavy stuff.
SHELL ["/bin/bash", "-e", "-c"]
WORKDIR /src
RUN git -c advice.detachedHead=false clone https://gitlab.freedesktop.org/emersion/libdisplay-info.git libdisplay-info
RUN git -c advice.detachedHead=false clone -b jellyfin-mpp --depth=1 https://github.com/nyanmisaka/mpp.git rkmpp
RUN git -c advice.detachedHead=false clone -b jellyfin-rga --depth=1 https://github.com/nyanmisaka/rk-mirrors.git rkrga
RUN git -c advice.detachedHead=false clone --depth=1 https://github.com/nyanmisaka/ffmpeg-rockchip.git ffmpeg
RUN git -c advice.detachedHead=false clone https://github.com/xbmc/xbmc.git kodi

#### Builds

# We'll build into /usr/local, so zero that out to get a clean slate. Yeah, it's stupid, but it works.
RUN rm -rfv /usr/local/*

# RKMPP
WORKDIR /src/rkmpp/rkmpp_build
RUN pipetty cmake -DCMAKE_INSTALL_PREFIX=/usr/local -DCMAKE_BUILD_TYPE=Release -DBUILD_SHARED_LIBS=ON -DBUILD_TEST=OFF ..
RUN pipetty make -j$(nproc)
RUN pipetty make install

# RKRGA
WORKDIR /src
RUN meson setup rkrga rkrga_build --prefix=/usr/local --libdir=lib --buildtype=release --default-library=shared -Dcpp_args=-fpermissive -Dlibdrm=false -Dlibrga_demo=false
RUN meson configure rkrga_build
RUN pipetty ninja -C rkrga_build install

# ffmpeg, with rkxxx stuff. Nyanmisaka's fork, full of boogie goodness. You folks rock.
WORKDIR /src/ffmpeg
RUN pipetty ./configure --prefix=/usr/local --enable-gpl --enable-version3 --enable-libdrm --enable-rkmpp --enable-rkrga
RUN pipetty make -j $(nproc)
RUN pipetty make install

# Libdisplay-info, a hard dependency for kodi GBM.
WORKDIR /src/libdisplay-info
RUN mkdir build && cd build && meson setup --prefix=/usr/local --buildtype=release .. && ninja && ninja install

# Kodi itself; first, pick boogie's patches. Cherry pick the last 2 commits from boogie's branch.
WORKDIR /src/kodi
RUN git config --global user.email "you@example.com" && git config --global user.name "Your Name"
RUN git remote add boogie https://github.com/hbiyik/xbmc.git
RUN git fetch boogie gbm_drm_dynamic_afbc_video_planes:gbm_drm_dynamic_afbc_video_planes
RUN git cherry-pick gbm_drm_dynamic_afbc_video_planes~2..gbm_drm_dynamic_afbc_video_planes
RUN git log -n 10

# Kodi build. the --build step actually downloads things and that might fail, so retry it a few times.
WORKDIR /src/kodi-build
RUN pipetty cmake ../kodi -DCMAKE_INSTALL_PREFIX=/usr/local -DCORE_PLATFORM_NAME=gbm -DAPP_RENDER_SYSTEM=gles -DENABLE_INTERNAL_FMT=ON -DENABLE_INTERNAL_FLATBUFFERS=ON
RUN pipetty cmake --build . -- -j$(nproc) || pipetty cmake --build . -- -j$(nproc) || pipetty cmake --build . -- -j$(nproc) 
RUN pipetty make install

# Drop headers for now. We don't need them in the final package.
RUN rm -rf /usr/local/include

### ------- packaging
WORKDIR /pkg/src/usr
RUN cp -pr /usr/local /pkg/src/usr/

# Prepare debian binary package
WORKDIR /pkg/src
ADD debian /pkg/src/debian
# For DRM Prime enablement; systemd unit copies it to .kodi/userdata on first run.
ADD userdata/guisettings.xml /pkg/src/usr/local/share/kodi/userdata/guisettings.xml

# For Pulseaudio, we need to add a system.pa file. This is a hack.
# The unit file sets env PULSE_CONFIG_PATH=/usr/local/share/pulse-kodi
WORKDIR /pkg/src/usr/local/share/pulse-kodi
ADD pulseaudio/system.pa /pkg/src/usr/local/share/pulse-kodi/system.pa

WORKDIR /pkg/src
RUN echo "usr/*" > debian/kodi-rockchip-gbm.install

# Create the "Architecture:" field in control; ARG invalidates the cache.
ARG OS_ARCH="arm64"
RUN echo "Architecture: ${OS_ARCH}" >> /pkg/src/debian/control
RUN cat /pkg/src/debian/control

# Create the Changelog, fake. ARG here invalidates the cache.
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

