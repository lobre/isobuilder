#!/bin/bash
#
# This script will extract, modify and repack a bootable Ubuntu desktop iso image.
#
# Features:
#  - Add files to iso
#  - Add files into the filesystem
#  - Play scripts in a chroot of the filesystem
#
# Dependencies:
#  - genisoimage
#  - isohybrid
#  - mksquashfs
# 
# It should be run as root.
# sudo -H ./isobuilder.sh -- ubuntu-18.04.2-desktop-amd64.iso
# 
# It should be run from a system that has the same version as
# the one you want to build.

set -e

# Dependencies
deps="genisoimage isohybrid mksquashfs"

# Flags
action=false
unsquashfs=false

# Initialize our own variables:
output="./output.iso"
workdir="$HOME/.cache/isobuilder"
push=()
files=()
commands=()
scripts=()
interactive=false

function usage {
    echo "Usage: $(basename $0) [OPTION]... isofile.iso"
    echo "  -o <file.iso>   output iso file path (default: $output)"
    echo "  -w <workdir>    working directory used internally"
    echo "                  and cleaned when terminated (default: $workdir)"
    echo "  -p <file/dir>   push or replace file/directory in iso (form <file/dir> to copy at root in iso or <file/dir>:<dest>)"
    echo "                  (can be used multiple times)"
    echo "  -f <file/dir>   add file/directory to chroot (form <file> to copy in /tmp or <file/dir>:<dest>)"
    echo "                  (can be used multiple times)"
    echo "  -c <command>    run command in chroot (can be used multiple times)"
    echo "  -s <script.sh>  play script in chroot (can be used multiple times)"
    echo "  -i              interactive chroot (quit with exit)"
    echo "  -h              display help"
}

# The variable OPTIND holds the number of options parsed by the last call to getopts
OPTIND=1         # Reset in case getopts has been used previously in the shell.

while getopts "o:w:p:f:c:s:ih" opt; do
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

    p)  src=$OPTARG
        if [[ $src == *":"* ]]; then
            IFS=':' read -r -a parts <<< "$src"
            src=${parts[0]}
        fi

        if [ ! -e "$src" ]; then
            echo "$src is not a valid file/directory"
            exit 1 
        fi

        push+=("$OPTARG")
        action=true
        ;;

    f)  src=$OPTARG
        if [[ $src == *":"* ]]; then
            IFS=':' read -r -a parts <<< "$src"
            src=${parts[0]}
        fi

        if [ ! -e "$src" ]; then
            echo "$src is not a valid file/directory"
            exit 1 
        fi
        
        files+=("$OPTARG")
        action=true
        unsquashfs=true
        ;;

    c)  commands+=("$OPTARG")
        action=true
        unsquashfs=true
        ;;

    s)  if [ ! -f "$OPTARG" ]; then
            echo "$OPTARG is not a valid file"
            exit 1 
        fi

        scripts+=("$OPTARG")
        action=true
        unsquashfs=true
        ;;
        
    i)  interactive=true
        action=true
        unsquashfs=true
        ;;

    esac
done

shift $((OPTIND-1))

# Ignore -- if existing
[ "${1:-}" = "--" ] && shift

# Check if there is anything to do
if ! $action; then
    echo "nothing to do"
    exit 0
fi

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
    if [ -d "$workdir" ]; then
        echo "> Cleaning working directory..."

        umount -lf $workdir/squashfs/proc 2> /dev/null || true
        umount -lf $workdir/squashfs/sys 2> /dev/null || true
        umount -lf $workdir/squashfs/dev/pts 2> /dev/null || true
        umount -lf $workdir/squashfs/dev 2> /dev/null || true
        umount -lf /mnt 2> /dev/null || true

        rm -rf $workdir 2> /dev/null || true
    fi
}

# Set up the cleanup on signal with trap
trap "cleanup; trap - EXIT; exit" ERR INT TERM EXIT

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

# If any operation requiring to extract squashfs
if $unsquashfs; then

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
    mount --bind /dev $workdir/squashfs/dev
    mount --bind /dev/pts $workdir/squashfs/dev/pts

    cp /etc/resolv.conf $workdir/squashfs/etc/resolv.conf
    cp /etc/hosts $workdir/squashfs/etc/hosts
    cp /etc/apt/sources.list $workdir/squashfs/etc/apt/sources.list

    # Copy files/directories into chroot
    for f in "${files[@]}"; do
        src=$f
        dest=tmp/

        if [[ $f == *":"* ]]; then
            IFS=':' read -r -a parts <<< "$f"
            src=${parts[0]}
            dest=${parts[1]}
        fi

        # Remove leading slash
        dest=${dest#/}

        echo "> Copying $src into chroot at $dest..."
        cp -rf $src $workdir/squashfs/$dest
    done

    # Run scripts into chroot
    for script in "${scripts[@]}"; do

        # get file name with extension from path
        script_name=$(basename $script)

        echo "> Copying $script into chroot..."
        cp $script $workdir/squashfs/tmp/$script_name
        chmod +x $workdir/squashfs/tmp/$script_name

        echo "> Executing $script into chroot..."
        chroot $workdir/squashfs /bin/bash -c "/tmp/$script_name"

        echo "> Deleting $script from chroot..."
        rm -f $workdir/squashfs/tmp/$script_name
    done

    # Execute commands into chroot
    for cmd in "${commands[@]}"; do
        echo "> Executing $cmd into chroot..."
        chroot $workdir/squashfs /bin/bash -c "$cmd"
    done

    # Interactive console in chroot
    if $interactive; then
        echo "> Entering interactive chroot..."
        chroot $workdir/squashfs /bin/bash
    fi

    # Cleaning chroot
    echo "> Cleaning chroot..."
    chroot $workdir/squashfs umount -lf /sys 2> /dev/null || true
    chroot $workdir/squashfs umount -lf /proc 2> /dev/null || true
    chroot $workdir/squashfs umount -lf /dev/pts 2> /dev/null || true
    chroot $workdir/squashfs umount -lf /dev 2> /dev/null || true

    rm $workdir/squashfs/etc/resolv.conf
    rm $workdir/squashfs/etc/hosts

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
fi

###
# Push files in iso
###
echo "[Push files in ISO]"   
for p in "${push[@]}"; do
    src=$p
    dest=""
        
    if [[ $src == *":"* ]]; then
        IFS=':' read -r -a parts <<< "$src"
        src=${parts[0]}
        dest=${parts[1]}
    fi

    # Remove leading slash
    dest=${dest#/}

    echo "> Pushing $src file into iso..."
    cp -rf $src $workdir/iso/$dest
done

###
# Pack iso
#
echo "[Pack iso]"   

# Recalculate checksum
echo "> Recalculating checksum..."
bash -c "find $workdir/iso -path ./isolinux -prune -o -type f -not -name md5sum.txt -print0 | xargs -0 md5sum | tee $workdir/iso/md5sum.txt"

# Pack iso
echo "> Creating new iso..."
genisoimage -o $output -allow-limited-size -r -J -no-emul-boot -boot-load-size 4 -boot-info-table -b isolinux/isolinux.bin -c isolinux/boot.cat $workdir/iso 

# Make bootable on usb
echo "> Make bootable on usb..."
isohybrid $output
