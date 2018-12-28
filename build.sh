#!/bin/bash
rm kernel/kernel.com
rm img/olos.dsk
cd boot
nasm boot.asm -o boot.bin -f bin
cd ..
cp boot/boot.bin img/boot.bin
cd kernel
nasm kernel.asm -o kernel.sys
cd ..
cd img
rm os.dsk
mkfs.vfat emptydsk.dsk
sudo mount -t vfat -o loop,rw,gid=1000,uid=1000 emptydsk.dsk /media/myos/
cp ../kernel/kernel.sys /media/myos
cp ../cmd/*.com /media/myos
sudo umount /media/myos
nasm concat.asm -o olos.dsk -f bin
# qemu-system-x86_64 -fda olos.dsk
