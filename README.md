# isobuilder

It allows an Ubuntu desktop ISO to be customised and repacked to create a new ISO.

## Usage

    Usage: isobuilder.sh [OPTION]... isofile.iso
      -o       output iso file path (default: ./output.iso)
      -w       working directory used internally
               and cleaned when terminated (default: /home/lbrevet/.cache/isobuilder)
      -k       kickstart file path
      -p       add post install file for kickstart (can be used multiple times)
      -f       add file to chroot (form <file> to copy in /tmp or <file>:<dest>)
               (can be used multiple times)
      -c       run command in chroot (can be used multiple times)
      -s       play script in chroot (can be used multiple times)
      -h       display help

## Docker

    docker run -it --rm --privileged -v $(pwd)/ubuntu-18.04.2-desktop-amd64.iso:/root/ubuntu.iso lobre/isobuilder -h

Other example.

    docker run -it --rm --privileged -v $(pwd):/root/workdir lobre/isobuilder -k ks.cfg -- ubuntu-18.04.2-desktop-amd64.iso
