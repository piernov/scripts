#!/bin/bash

name="Arch Linux EFIStub"
kernel="\vmlinuz"
rootfs="UUID=e3636d97-fb46-40cd-9bf0-4daad16e528e"
initrd="\initramfs.img"
cmdline="initrd=${initrd} root=${rootfs} rootfstype=ext4 resume=UUID=c0070a8d-56d9-4294-8621-f395cc37db1a rw add_efi_memmap quiet splash i915.enable_rc6=1 i915.enable_fbc=1 i915.lvds_downclock=1 drm.vblankoffdelay=1 i915.semaphores=1 pcie_aspm=force usbcore.autosuspend=1 nmi_watchdog=0 i915.enable_psr=1"
disk="/dev/sdb"
part=1

echo $cmdline | iconv -f ascii -t ucs2 | efibootmgr -c -g -d ${disk} -p ${part} -L "${name}" -l "${kernel}" -@ -
