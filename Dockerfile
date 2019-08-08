FROM ubuntu:18.04

RUN apt-get update && apt-get install -y \
    git \
    genisoimage \
    syslinux-utils \
    squashfs-tools \
    rsync \
 && rm -rf /var/lib/apt/lists/*

COPY isobuilder.sh /usr/local/bin/isobuilder

RUN chmod +x /usr/local/bin/isobuilder

RUN mkdir /root/workdir

WORKDIR /root/workdir

ENTRYPOINT ["/usr/local/bin/isobuilder"]
