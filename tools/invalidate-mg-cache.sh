#!/bin/sh
# Invalidate MobileGestalt's on-disk answer cache on the iOS root (vince).
#
# The cache is built on the first boots and can keep stale artwork-identity
# answers (ArtworkTraits with only ArtworkDeviceScaleFactor) after the ADT gets
# the real D22AP /product node. UIKit then cannot resolve
# BoundingPathBitmap-1125x2436-375x812-3.00x and SpringBoard aborts in a loop.
#
# This does NOT reflash anything: it writes 16 zero bytes over the bplist magic
# of one regenerable cache file in /dev/block/mmcblk0p50 (HFS block 3145827).
# Run from OrangeFox recovery with adb root. The pristine artifacts/ios-root.img
# and .simg do NOT contain this file (the bytes are already zero), so reflashing
# them clears the cache too.
set -eu

DEV=/dev/block/mmcblk0p50
BLK=3145827
OFF=$((BLK * 4096))          # 12885307392
COUNT=16
BACKUP=${1:-/tmp/opencode/hfs/mgcache.bin}

echo "device: $DEV  offset: $OFF  bytes: $COUNT"
adb shell "test -b $DEV" || { echo "no block device - are you in OrangeFox?"; exit 1; }

magic=$(adb exec-out "dd if=$DEV bs=1 skip=$OFF count=8 2>/dev/null" | od -An -tx1 | tr -d ' \n')
echo "current magic: $magic"
if [ "$magic" = "0000000000000000" ]; then
    echo "already invalidated; nothing to do"
    exit 0
fi
if [ "$magic" != "62706c6973743030" ]; then      # 'bplist00'
    echo "unexpected magic (not a bplist) - refusing to write"
    exit 1
fi

mkdir -p "$(dirname "$BACKUP")"
adb exec-out "dd if=$DEV bs=1 skip=$OFF count=6852 2>/dev/null" > "$BACKUP"
echo "backup: $BACKUP ($(wc -c < "$BACKUP") bytes)"
adb shell "dd if=/dev/zero of=$DEV bs=1 seek=$OFF count=$COUNT conv=notrunc" >/dev/null
echo "cache invalidated; boot with fastboot boot boot-parches2.img"
