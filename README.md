# isobuilder

It allows an Ubuntu desktop ISO to be customised and repacked to create a new ISO.

## Usage

    Usage: isobuilder.sh [OPTION]... isofile.iso
      -o <file.iso>   output iso file path (default: ./output.iso)
      -w <workdir>    working directory used internally
                      and cleaned when terminated (default: /home/dev/.cache/isobuilder)
      -k <ks.cfg>     kickstart file path
      -p <script.sh>  add post install file for kickstart (can be used multiple times)
      -f <file.txt>   add file to chroot (form <file> to copy in /tmp or <file>:<dest>)
                      (can be used multiple times)
      -c <command>    run command in chroot (can be used multiple times)
      -s <script.sh>  play script in chroot (can be used multiple times)
      -i              interactive chroot (quit with exit)
      -h              display help

## Docker

    docker run -it --rm --privileged -v $(pwd)/ubuntu-18.04.2-desktop-amd64.iso:/root/ubuntu.iso lobre/isobuilder -h

Other example.

    docker run -it --rm --privileged -v $(pwd):/root/workdir lobre/isobuilder -k ks.cfg -- ubuntu-18.04.2-desktop-amd64.iso
