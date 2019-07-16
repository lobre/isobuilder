FROM ubuntu:18.04

RUN apt-get update && apt-get install -y \
    git \
    genisoimage \
    syslinux-utils \
    squashfs-tools \
 && rm -rf /var/lib/apt/lists/*

COPY isobuilder.sh /usr/local/bin/isobuilder

RUN chmod +x /usr/local/bin/isobuilder

WORKDIR /root

ENTRYPOINT ["/usr/local/bin/isobuilder"]
