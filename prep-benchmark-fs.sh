#!/bin/bash

set -o nounset
set -o errexit
set -o errtrace
set -o pipefail

while getopts "hd:m:f:" arg; do
    case $arg in
	h)
	    usage
	    exit 0
	    ;;
	d)
	    DEV=$OPTARG
	    ;;
	m)
	    MNT=$OPTARG
	    ;;
	f)
	    FS=$OPTARG
	    ;;
    esac
done

if [[ -z ${DEV-} ]]; then
    echo "Required parameter -d missing: device to test"
    exit 1
fi

if [[ -z ${MNT-} ]]; then
    echo "Required parameter -m missing: mount point"
    exit 1
fi

if [[ -z ${FS-} ]]; then
    echo "Required parameter -f missing: filesystem type"
    exit 1
fi

umount $DEV >/dev/null 2>&1 || true
umount $MNT >/dev/null 2>&1 || true

blkdiscard -s	$DEV >/dev/null 2>&1 ||
    blkdiscard	$DEV >/dev/null 2>&1 ||
    true

wipefs -af $DEV

case $FS in
    bcache)
	bcache format -f $DEV
	;;
    ext4)
	mkfs.ext4 -F $DEV
	;;
    ext4-no-journal)
	mkfs.ext4 -F -O ^has_journal $DEV
	;;
    xfs)
	mkfs.xfs -f $DEV
	;;
    btrfs)
	mkfs.btrfs -f $DEV
	;;
esac

mount $DEV $MNT
