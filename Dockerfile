ARG BASE_IMAGE="debian:bookworm"
FROM ${BASE_IMAGE} as build

ARG OS_ARCH="arm64"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update
RUN apt-get -y dist-upgrade
RUN apt-get -y install git bash wget curl build-essential devscripts debhelper pkg-config cmake meson
RUN apt-get -y install tree colorized-logs # for pipetty
SHELL ["/bin/bash", "-e", "-c"]


# Build stuff from source
FROM build as mediaplayer

RUN apt-get -y install libdrm-dev

WORKDIR /src
RUN git -c advice.detachedHead=false clone -b jellyfin-mpp --depth=1 https://github.com/nyanmisaka/mpp.git /src/rkmpp
WORKDIR /src/rkmpp/rkmpp_build

RUN pipetty cmake     -DCMAKE_INSTALL_PREFIX=/usr/local     -DCMAKE_BUILD_TYPE=Release     -DBUILD_SHARED_LIBS=ON     -DBUILD_TEST=OFF ..
RUN pipetty make -j$(nproc)
RUN pipetty make install


# Prepare the results in /out
FROM build as packager

WORKDIR /out/usr
COPY --from=mediaplayer /usr/local .
RUN cp -vp /bin/bash /out/usr/bin/something
RUN tree /out

# Prepare debian binary package
WORKDIR /pkg/src
ADD debian /pkg/src/debian
RUN cp -rvp /out/* /pkg/src/
# Create the .install file with the binaries to be installed, without leading slash
RUN find /out -type f | sed -e 's/^\/out\///g' > debian/k8s-worker-containerd.install

# Create the "Architecture: amd64" field in control
RUN echo "Architecture: ${OS_ARCH}" >> /pkg/src/debian/control
RUN cat /pkg/src/debian/control

# Create the Changelog, fake. The atrocities we do in dockerfiles.
ARG PACKAGE_VERSION="20210928"
RUN echo "k8s-worker-containerd (${PACKAGE_VERSION}) stable; urgency=medium" >> /pkg/src/debian/changelog
RUN echo "" >> /pkg/src/debian/changelog
RUN echo "  * Not a real changelog. Sorry." >> /pkg/src/debian/changelog
RUN echo "" >> /pkg/src/debian/changelog
RUN echo " -- Ricardo Pardini <ricardo@pardini.net>  Wed, 15 Sep 2021 14:18:33 +0200" >> /pkg/src/debian/changelog
RUN cat /pkg/src/debian/changelog


# Build the package, don't sign it, don't lint it, compress fast with xz
WORKDIR /pkg/src
RUN tree /pkg/src
RUN cat debian/k8s-worker-containerd.install
RUN debuild --no-lintian --build=binary -us -uc -Zxz -z1 
RUN file /pkg/*.deb

# Show package info
RUN dpkg-deb -I /pkg/*.deb || true
RUN dpkg-deb -f /pkg/*.deb || true

# Install it to make sure it works
RUN dpkg -i /pkg/*.deb
# @TODO --versions and such
RUN dpkg -L k8s-worker-containerd

RUN lsb_release -a

# Now prepare the real output: a tarball of /out, and the .deb for this arch.
WORKDIR /artifacts
RUN cp -v /pkg/*.deb k8s-worker-containerd_${OS_ARCH}_$(lsb_release -c -s).deb
WORKDIR /out
RUN tar czvf /artifacts/k8s-worker-containerd_${OS_ARCH}_$(lsb_release -c -s).tar.gz *

# Final stage is just alpine so we can start a fake container just to get at its contents using docker in GHA
FROM alpine:3
COPY --from=packager /artifacts/* /out/

