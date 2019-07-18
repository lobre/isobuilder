# isobuilder

It allows an Ubuntu desktop ISO to be customised and repacked to create a new ISO.

It brings a simple way to insert a Kickstart file. If you need to add a preseed file however, 
you will have to use the `-p` option to push it, and to push as well a version of `isolinux/txt.cfg`
to add a new boot entry.

## Usage

    Usage: isobuilder [OPTION]... isofile.iso
      -o <file.iso>   output iso file path (default: ./output.iso)
      -w <workdir>    working directory used internally
                      and cleaned when terminated (default: /root/.cache/isobuilder)
      -k <ks.cfg>     kickstart file path
      -p <file.txt>   push or replace file in iso (form <file> to copy at root in iso or <file>:<dest>)
                      (can be used multiple times)
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
