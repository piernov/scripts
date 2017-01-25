#!/bin/bash
var="quiet loglevel=3 udev.log-priority=3 rd.udev.log-priority=3 rd.systemd.show_status=auto resume=UUID=2ff4e65f-3a27-46cc-adc4-d78fc82b5762 \
pcie_aspm=force nmi_watchdog=0 pcie_aspm.policy=powersave i915.enable_rc6=7 i915.enable_psr=1 i915.enable_dc=2 i915.enable_fbc=1 i915.fastboot=1 \
drm.vblankoffdelay=1 i915.enable_guc_loading=2 i915.enable_guc_submission=2"

sudo efibootmgr -b 0000 -B
sudo efibootmgr -d /dev/sda -p 1 -c -L ArchLinux -l /EFI/arch/vmlinuz-linux -u "root=UUID=7382b063-aad0-447a-a86e-814b612809c8 rw initrd=/EFI/arch/intel-ucode.img initrd=/EFI/arch/initramfs-linux.img ${var}"
