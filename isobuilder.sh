#!/bin/bash
#
# This script will extract, modify and repack a bootable iso image.
#
# Features:
#  - Add kickstart file
#  - Add post install kickstart scripts 
#  - Play scripts in a chroot of the filesystem
#
# Dependencies:
#  - genisoimage
#  - isohybrid
# 
# It should be run as root.
# sudo -H ./isobuilder.sh -- ubuntu-18.04.2-desktop-amd64.iso
#
# It has been developed using the following link.
# https://doc.ubuntu-fr.org/personnaliser_livecd

set -e

# Dependencies
deps="genisoimage isohybrid"

# Initialize our own variables:
output="./output.iso"
workdir="$HOME/.cache/isobuilder"
kickstart=""
postscripts=()
files=()
commands=()
scripts=()

function usage {
    echo "Usage: $(basename $0) [OPTION]... isofile.iso"
    echo "  -o       output iso file path (default: $output)"
    echo "  -w       working directory used internally"
    echo "           and cleaned when terminated (default: $workdir)"
    echo "  -k       kickstart file path"
    echo "  -p       add post install file for kickstart (can be used multiple times)"
    echo "  -f       add file to chroot (form <file> to copy in /tmp or <file>:<dest>)"
    echo "           (can be used multiple times)"
    echo "  -c       run command in chroot (can be used multiple times)"
    echo "  -s       play script in chroot (can be used multiple times)"
    echo "  -h       display help"
}

# The variable OPTIND holds the number of options parsed by the last call to getopts
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "o:w:k:p:f:c:s:h" opt; do
    case "$opt" in
    h|\?)
        usage
        exit 0
        ;;
    :)
        echo "Invalid option: $OPTARG requires an argument"
        exit 1
        ;;
    o)  output=$OPTARG
        ;;
    w)  workdir=$OPTARG
        ;;
    k)  kickstart=$OPTARG
        ;;
    p)  postscripts+=("$OPTARG")
        ;;
    f)  files+=("$OPTARG")
        ;;
    c)  commands+=("$OPTARG")
        ;;
    s)  scripts+=("$OPTARG")
        ;;
    esac
done

shift $((OPTIND-1))

# Ignore -- if existing
[ "${1:-}" = "--" ] && shift

# Check iso arguments provided
iso=$1
if [ -z "$iso" ]; then
    usage
    exit 1
fi 

# Check iso file exists
if [ ! -f "$iso" ]; then
    echo "provided iso file $iso is not a valid path"
    exit 1 
fi

# Check dependencies are installed
for dep in $deps
do
    if ! type "$dep" > /dev/null 2>&1; then
        echo "$dep package is required and missing in the current path"
        exit 1
    fi
done

# Cleanup function
cleanup() {
    echo "> Cleaning working directory..."

    umount $workdir/squashfs/proc 2> /dev/null || true
    umount $workdir/squashfs/sys 2> /dev/null || true
    umount $workdir/squashfs/dev/pts 2> /dev/null || true
    umount /mnt 2> /dev/null || true

    rm -rf $workdir
}

# Set up the cleanup on signal with trap
trap "cleanup; exit" ERR INT TERM EXIT

# Make sure previous build in cleaned up
cleanup > /dev/null

# Recreate a clean working dir
mkdir -p $workdir/iso
mkdir -p $workdir/squashfs

###
# Iso extract
#
echo "[ISO extract]"

# Mount iso file
echo "> Mounting iso..."
mount -o loop $iso /mnt 2> /dev/null

# Copy iso content into working directory
echo "> Copying iso content into working directory..."
cp -a /mnt/. $workdir/iso

# Unmount iso file
echo "> Unmounting iso..."
umount /mnt 2> /dev/null

###
# Squashfs extract
#
echo "[Squashfs extract]"   

# Mount squashfs filesystem
echo "> Mounting squashfs..."
mount -t squashfs -o loop $workdir/iso/casper/filesystem.squashfs /mnt 2> /dev/null

# Copy squashfs content into working directory
echo "> Copying squashfs content into working directory..."
cp -a /mnt/. $workdir/squashfs

# Unmount squashfs
echo "> Unmounting squashfs..."
umount /mnt 2> /dev/null

###
# Chroot
#
echo "[Chroot]"

# Preparing chroot
echo "> Preparing chroot"
mount --bind /proc $workdir/squashfs/proc
mount --bind /sys $workdir/squashfs/sys
mount -t devpts none $workdir/squashfs/dev/pts
cp /etc/resolv.conf $workdir/squashfs/etc/resolv.conf
cp /etc/hosts $workdir/squashfs/etc/hosts

# Copy files into chroot
for f in "${files[@]}"; do
    src=$f
    dest=/tmp/

    if [[ $f == *":"* ]]; then
        IFS=':' read -r -a parts <<< "$f"
        src=${parts[0]}
        dest=${parts[1]}
    fi

    echo "> Copying $src into chroot at $dest..."
    cp $src $workdir/squashfs/$dest
done

# Run scripts into chroot
for script in "${scripts[@]}"; do
    echo "> Copying $script into chroot..."
    cp $script $workdir/squashfs/tmp/$script
    chmod +x $workdir/squashfs/tmp/$script

    echo "> Executing $script into chroot..."
    chroot $workdir/squashfs /tmp/$script

    echo "> Deleting $script from chroot..."
    rm -f $workdir/squashfs/tmp/$script
done

# Execute commands into chroot
for cmd in "${commands[@]}"; do
    echo "> Executing $cmd into chroot..."
    chroot $workdir/squashfs /bin/bash -c "$cmd"
done

# Cleaning chroot
echo "> Cleaning chroot..."
chroot $workdir/squashfs umount -lf /sys 2> /dev/null || true
chroot $workdir/squashfs umount -lf /proc 2> /dev/null || true
chroot $workdir/squashfs umount -lf /dev/pts 2> /dev/null || true
rm $workdir/squashfs/etc/resolv.conf
rm $workdir/squashfs/etc/hosts

# Insert kickstart
if [ ! -z "$kickstart" ]; then

    ###
    # Kickstart
    ###
    echo "[Kickstart]"   

    echo "> Adding kickstart file..."
    cp $kickstart $workdir/ks.cfg

    echo "> Adding kickstart to boot options..."
    sed -i 's/append\ initrd\=initrd.img/append initrd=initrd.img\ ks\=cdrom:\/ks.cfg/' $workdir/iso/isolinux.cfg

    # Copy post script files
    for p in "${postscripts[@]}"; do
        cp $p $workdir/iso/$p
    done
fi

###
# Pack squashfs
#
echo "[Pack squashfs]"   

# Generating manifest
echo "> Regenerating manifest..."
chmod a+w $workdir/iso/casper/filesystem.manifest
chroot $workdir/squashfs dpkg-query -W --showformat='${Package} ${Version}\n' > $workdir/iso/casper/filesystem.manifest
chmod go-w $workdir/iso/casper/filesystem.manifest

# Remove old squashfs
echo "> Removing old squashfs..."
rm $workdir/iso/casper/filesystem.squashfs

# Create new squashfs
echo "> Creating new squashfs..."
mksquashfs $workdir/squashfs $workdir/iso/casper/filesystem.squashfs -info

###
# Pack iso
#
echo "[Pack iso]"   

# Recalculate checksum
echo "> Recalculating checksum..."
bash -c "find $workdir/iso -path ./isolinux -prune -o -type f -not -name md5sum.txt -print0 | xargs -0 md5sum | tee $workdir/iso/md5sum.txt"

# Pack iso
echo "> Creating new iso..."
genisoimage -o $output -r -J -no-emul-boot -boot-load-size 4 -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat $workdir/iso 

# Make bootable on usb
echo "> Make bootable on usb..."
isohybrid $output
