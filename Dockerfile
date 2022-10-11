FROM ubuntu:22.04

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
    git \
    genisoimage \
    syslinux-utils \
    squashfs-tools \
    rsync \
    dumpet \
 && rm -rf /var/lib/apt/lists/*

COPY isobuilder.sh /usr/local/bin/isobuilder

RUN chmod +x /usr/local/bin/isobuilder

RUN mkdir /root/workdir

WORKDIR /root/workdir

ENTRYPOINT ["/usr/local/bin/isobuilder"]
