# isobuilder

It allows an Ubuntu ISO to be customised and repacked to create a new ISO.

## Usage

    docker run -it --rm --privileged -v $(pwd)/ubuntu-18.04.2-desktop-amd64.iso:/root/ubuntu.iso lobre/isobuilder -h

Other example.

    docker run -it --rm --privileged -v $(pwd)/ubuntu-18.04.2-desktop-amd64.iso:/root/ubuntu.iso -v $(pwd):/output lobre/isobuilder -o /output/new-ubuntu.iso -c "apt install htop" -- ubuntu.iso
