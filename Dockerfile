ARG BASE_IMAGE="debian:bookworm"
FROM ${BASE_IMAGE} as build

ARG OS_ARCH="arm64"

ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get -y update
RUN apt-get -y dist-upgrade
RUN apt-get -y install git bash wget curl build-essential devscripts debhelper pkg-config
SHELL ["/bin/bash", "-e", "-c"]


# Build rkmpp from source
FROM build as mediaplayer
WORKDIR /src
ARG RUNC_VERSION="v1.1.14"
RUN git -c advice.detachedHead=false clone --depth=1  --single-branch --branch=${RUNC_VERSION} https://github.com/opencontainers/runc /src/runc
WORKDIR /src/runc
RUN make


# Prepare the results in /out
FROM build as packager
WORKDIR /out/usr/sbin
COPY --from=runc /src/runc/runc .

WORKDIR /out/usr/bin
COPY --from=cri-tools /src/cri-tools/build/bin/linux/${OS_ARCH}/crictl crictl-latest
COPY --from=cri-tools /src/cri-tools/build/bin/linux/${OS_ARCH}/critest .
COPY --from=containerd /src/containerd/bin/* .
#COPY --from=podman /src/podman/bin/podman .
#COPY --from=conmon /src/conmon/bin/conmon .
COPY --from=cfssl /src/cfssl/bin/cfssl .
COPY --from=cfssl /src/cfssl/bin/cfssljson .
COPY --from=nerdctl /src/nerdctl/_output/nerdctl .

# add podman default configs
#WORKDIR /out/etc/containers
#RUN curl -L -o /out/etc/containers/registries.conf https://src.fedoraproject.org/rpms/containers-common/raw/main/f/registries.conf
#RUN curl -L -o /out/etc/containers/policy.json https://src.fedoraproject.org/rpms/containers-common/raw/main/f/default-policy.json

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
RUN debuild --no-lintian --build=binary -us -uc -Zxz -z1 
RUN file /pkg/*.deb

# Show package info
RUN dpkg-deb -I /pkg/*.deb || true
RUN dpkg-deb -f /pkg/*.deb || true

# Install it to make sure it works
RUN dpkg -i /pkg/*.deb
RUN runc --version
RUN containerd --version
RUN crictl-latest --version # Real bin
RUN crictl --version # symlink in usr/local/bin
#RUN podman --version
#RUN conmon --version
RUN cfssl version
RUN cfssljson --version
RUN nerdctl --version
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

