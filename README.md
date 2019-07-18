# isobuilder

It allows an Ubuntu desktop ISO to be customised and repacked to create a new ISO.

## Usage

    Usage: isobuilder [OPTION]... isofile.iso
      -o <file.iso>   output iso file path (default: ./output.iso)
      -w <workdir>    working directory used internally
                      and cleaned when terminated (default: /root/.cache/isobuilder)
      -p <file.txt>   push or replace file in iso (form <file> to copy at root in iso or <file>:<dest>)
                      (can be used multiple times)
      -f <file.txt>   add file to chroot (form <file> to copy in /tmp or <file>:<dest>)
                      (can be used multiple times)
      -c <command>    run command in chroot (can be used multiple times)
      -s <script.sh>  play script in chroot (can be used multiple times)
      -i              interactive chroot (quit with exit)
      -h              display help

## Docker

    // Display help
    docker run -it --rm --privileged -v $(pwd)/ubuntu-18.04.2-desktop-amd64.iso:/root/ubuntu.iso lobre/isobuilder -h

    // Add kickstart and new boot option in txt.cfg
    docker run -it --rm --privileged -v $(pwd):/root/workdir lobre/isobuilder -p "ks.cfg" -p "txt.cfg:isolinux/txt.cfg" -- ubuntu.iso
