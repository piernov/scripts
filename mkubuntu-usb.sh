#!/usr/bin/env bash

## Toolbox ##

# Configuration
filesystems=(
	"1 vfat -F16"
	"2 none"
	"3 ext4 -L casper-rw"
	"4 swap"
)

GRUB_PART="1"
GRUB_FS="vfat"
GRUB_UEFI="y"
GRUB_BIOS="y"
GRUB_ID="BOOT"
GRUB_BIN="grub-install"

WRITE_ISO="y"
ISO_PATH="/home/piernov/Téléchargements/ubuntu-15.10-desktop-amd64.iso"
SYSTEM_PART="2"
SYSTEM_FS="none"

WRITE_DATA="y"
DATA_PATH="/home/piernov/Téléchargements/ubuntu-data.tar.xz" # tar archive
DATA_PART="3"
DATA_FS="ext4"
CONF_DATA="y"

if [ -z "$DATA_HOSTNAME" ]; then
	DATA_HOSTNAME="jm2l-${RANDOM}"
fi

MOUNTDIR=/mnt

WTIMEOUT=5

# Declaration
created_mountpoints=()
mounted_filesystems=()

# Formatting

CBOLD="\e[1m"
CU="\e[4m"
CINV="\e[7m"
CRED="\e[31m"
CGREEN="\e[32m"
CCYAN="\e[36m"
CLYELL="\e[93m"
CCLR="\e[0m"

# Logging

function einfo {
	echo -e "${CGREEN}Info:${CCLR} $1"
}

function ewarn {
	echo -e "${CU}${CLYELL}Warning:${CCLR} $1"
}

function eerror {
	echo -e "${CRED}Error:${CCLR} ${1}" >&2
}

function pexec {
	local out
	local ret
	if [ -n $DEBUG ]; then
		echo -e "${CCYAN}-->${CCLR} $*"
	fi
	eval "$@"
	ret=$?
	if [ $ret -ne 0 ]; then
		eerror "${CBOLD}$* ${CCLR}failed."
	fi
	return $ret
}

function eusage {
	echo "Usage: $0 device"
}

# Various

function umount_filesystems {
	einfo "Umounting filesystems."
	for v in "${mounted_filesystems[@]}"; do
		einfo "Umounting filesystem $v"
		pexec umount "$v"
	done
}

function delete_mountpoints {
	einfo "Deleting mountpoints."
	for v in "${created_mountpoints[@]}"; do
		einfo "Deleting mountpoint $v"
		pexec rm -r "$v"
	done
}

function cleanup {
	umount_filesystems
	delete_mountpoints
}

function cleanup_and_exit {
	cleanup
	if [ $1 -eq 0 ]; then
		einfo "Success!"
	else
		eerror "Failure!"
	fi
	exit $1
}

## Actually do the work ##


# Cleaning device
function wipe_parttable {
	local device
	device="$1"
	einfo "Wiping firsts 2048 sectors of $device."
	pexec dd if=/dev/zero of="$device" bs=512 count=2048
	if [ $? -ne 0 ]; then
		exit 8
	fi
}

# Write the new partition table
function write_parttable {
	local device
	device="$1"
	einfo "Writing new partition table on $device"

	einfo "$device new partition table:"
	pexec sfdisk "$device" <<EOF
label: dos
unit: sectors

/dev/sdb1 : start=        2048, size=       65536, type=ef, bootable
/dev/sdb2 : start=       67584, size=     3145728, type=83
/dev/sdb3 : start=     3213312, size=    10663937, type=83
/dev/sdb4 : start=    13879296, size=     2095104, type=82
EOF

	if [ $? -ne 0 ]; then
		exit 9
	fi
        einfo "Synchronizing caches"
        pexec sync
}

function make_filesystems {
	local device
	device="$1"

	einfo "Creating filesystems on $1"
	for v in "${filesystems[@]}"; do
		local num
		local type
		local opts
		num="$(echo "$v"|cut -d' ' -f1)"
		type="$(echo "$v"|cut -s -d' ' -f2)"
		opts="$(echo "$v"|cut -s -d' ' -f3-)"

		if [ "$type" == "none" ]; then
			continue
		fi

		if [ -z "$opts" ]; then
			dispopts="<none>"
		else
			dispopts="\"$opts\""
		fi

		einfo "Creating filesystem $type on ${device}${num} with options ${dispopts}:"
		if [ "$type" == "swap" ]; then
			pexec mkswap ${device}${num} ${opts}
		else
			pexec mkfs.${type} ${device}${num} ${opts}
		fi

		if [ $? -ne 0 ]; then
			exit 10
		fi
	done
	einfo "Created filesystems"
        einfo "Synchronizing caches"
        pexec sync
}

function mount_partitions {
	local device
	device="$1"

	einfo "Mounting partitions."
	for v in "${filesystems[@]}"; do
		local num
		local type
		num="$(echo "$v"|cut -d' ' -f1)"
		type="$(echo "$v"|cut -s -d' ' -f2)"

		if [ "$type" == "none" ] || [ "$type" == "swap" ]; then
			continue
		fi

		mountpoint="${MOUNTDIR}/$(basename "${device}")${num}"

		einfo "Creating mount point ${mountpoint}"
		pexec mkdir -p ${mountpoint}
		if [ $? -ne 0 ]; then
			exit 11
		fi

		created_mountpoints+=("${mountpoint}")

		einfo "Mounting partition ${device}${num} as $type on ${mountpoint}:"
		pexec mount -t ${type} ${device}${num} ${mountpoint}

		if [ $? -ne 0 ]; then
			cleanup_and_exit 12
		fi

		mounted_filesystems+=("${device}${num}")
	done
}

function guess_part {
	local device
	local fs
	local part
	device="$1"
	fs="$2"

	einfo "Trying to guess the GRUB partition."
	for v in "${filesystems[@]}"; do
		local num
		local type
		num="$(echo "$v"|cut -d' ' -f1)"
		type="$(echo "$v"|cut -s -d' ' -f2)"

		if [ "$type" == "$fs" ]; then
			einfo "Found ${type} partition ${device}${num}."

			if [ "$fs" != "none" ] && ! grep -q "${device}${num}" /proc/mounts; then
				ewarn "${type} partition ${device}${num} not mounted."
			else
				part="$num"
			fi
		fi
	done
	if [ -z "$part" ]; then
		return 1
	else
		return 0
	fi
}

function guess_grub_part {
	local device
	device="$1"

	if [ -z "$GRUB_FS"]; then GRUB_FS="vfat"; fi

	GRUB_PART=$(guess_part "$device" "$GRUB_FS")

	if [ $? -ne 0 ]; then
		eerror "Couldn't find any suitable partition on device ${device}."
		echo "       Either set the $GRUB_PART variable to the correct partition,"
		echo "       or create add a vfat partition to the partition table,"
		echo "       or disable GRUB installation."
		cleanup_and_exit 13
	else
		einfo "Using ${GRUB_FS} partition ${device}${GRUB_PART} as GRUB partition"
	fi
}

function setup_grub_bios {
	local device
	local mountpoint
	device="$1"
	mountpoint="$2"

	einfo "Installing GRUB in mount point ${mountpoint}, with MBR boot sector in ${device}."
	pexec "${GRUB_BIN}" --no-floppy --target=i386-pc --root-directory="${mountpoint}" "${device}"
	if [ $? -ne 0 ]; then
		cleanup_and_exit 14
	fi
	einfo "GRUB for BIOS installed successfully"
}

function setup_grub_uefi {
	local device
	local mountpoint
	device="$1"
	mountpoint="$2"

	if [ -z "$GRUB_ID" ]; then GRUB_ID="boot"; fi

	einfo "Installing GRUB in mount point ${mountpoint}, with UEFI bootloader in ${mountpoint}/EFI/${GRUB_ID}."
	pexec "${GRUB_BIN}" --no-floppy --target=i386-efi --root-directory="${mountpoint}" --efi-directory="${mountpoint}" --bootloader-id="${GRUB_ID}" --no-nvram --recheck

	pexec "${GRUB_BIN}" --no-floppy --target=x86_64-efi --root-directory="${mountpoint}" --efi-directory="${mountpoint}" --bootloader-id="${GRUB_ID}" --no-nvram --recheck

	if [ $? -ne 0 ]; then
		cleanup_and_exit 15
	fi

	einfo "Copying grubx64.efi to bootx64.efi"
	pexec cp "${mountpoint}/EFI/${GRUB_ID}/grubx64.efi" "${mountpoint}/EFI/${GRUB_ID}/bootx64.efi"

	pexec cp "${mountpoint}/EFI/${GRUB_ID}/grubia32.efi" "${mountpoint}/EFI/${GRUB_ID}/bootia32.efi"

	if [ $? -ne 0 ]; then
		cleanup_and_exit 16
	fi

	einfo "GRUB for UEFI installed successfully"
}

function setup_grub_config {
	local mountpoint
	mountpoint="$1"

	einfo "Writing GRUB configuration file to ${mountpoint}/boot/grub/grub.cfg"
	pexec cat \> ${mountpoint}/boot/grub/grub.cfg <<EOF
if loadfont /boot/grub/fonts/unicode.pf2 ; then
	set gfxmode=auto
	insmod efi_gop
	insmod efi_uga
	insmod gfxterm
	terminal_output gfxterm
fi

set menu_color_normal=white/black
set menu_color_highlight=black/light-gray

menuentry "Try Ubuntu without installing" {
	set gfxpayload=keep
	linux	(hd0,2)/casper/vmlinuz.efi  file=/cdrom/preseed/ubuntu.seed boot=casper persistent quiet splash ---
	initrd	(hd0,2)/casper/initrd.lz
}
EOF

	if [ $? -ne 0 ]; then
		cleanup_and_exit 17
	fi
}

function setup_grub {
	if [ "${GRUB_BIOS}" != "y" ] && [ "${GRUB_UEFI}" != "y" ]; then
		ewarn "GRUB installation disabled."
		return
	fi

	if [ -z "$GRUB_PART" ]; then
		ewarn "No GRUB partition specified, will use the first mounted vfat partition available on the device."
		guess_grub_part "$1"
	elif ! grep -q "${1}${GRUB_PART}" /proc/mounts; then
		ewarn "Invalid GRUB partition specified, will use the first mounted vfat partition available on the device."
		guess_grub_part "$1"
	fi

	mountpoint=$(grep "${device}${GRUB_PART}" /proc/mounts | cut -d' ' -f2)

	if [ -z $GRUB_BIN ]; then
		GRUB_BIN="grub-install"
	fi
	if [ -n $DEBUG ]; then
		GRUB_BIN="${GRUB_BIN} --verbose"
	fi

	if [ "$GRUB_BIOS" == "y" ]; then
		setup_grub_bios "$1" "$mountpoint"
	else
		ewarn "GRUB BIOS setup disabled."
	fi
	if [ "$GRUB_UEFI" == "y" ]; then
		setup_grub_uefi "$1" "$mountpoint"
	else
		ewarn "GRUB UEFI setup disabled."
	fi

	setup_grub_config "$mountpoint"

	einfo "GRUB installed successfully to ${mountpoint}"
}

function guess_system_part {
        local device
        device="$1"

        if [ -z "$SYSTEM_FS"]; then SYSTEM_FS="none"; fi

        SYSTEM_PART=$(guess_part "$device" "$SYSTEM_FS")

        if [ $? -ne 0 ]; then
                eerror "Couldn't find any suitable partition on device ${device}."
                echo "       Either set the $SYSTEM_PART variable to the correct partition,"
                echo "       or create add an empty partition to the partition table,"
                echo "       or disable ISO installation."
                cleanup_and_exit 18
        else
                einfo "Using ${SYSTEM_FS} partition ${device}${SYSTEM_PART} as ISO destination partition"
        fi
}

function write_iso {
	local device
	device="$1"

        if [ "${WRITE_ISO}" != "y" ]; then
                ewarn "ISO installation disabled."
                return
        fi

        if [ -z "$SYSTEM_PART" ]; then
                ewarn "No ISO destination partition specified, will use the first empty partition available on the device."
                guess_system_part "$device"
        fi

	partsize="$(sfdisk -s "${device}${SYSTEM_PART}")"
	isosize="$(sfdisk -s "${ISO_PATH}")"
	if [ "$partsize" -lt "$isosize" ]; then
		eerror "ISO file ${ISO_PATH} is bigger ($isosize) than destination partition ${device}${SYSTEM_PART} ($partsize)"
		cleanup_and_exit 19
	fi

	einfo "Synchronizing caches"
	pexec sync

	einfo "Installing ISO in partition ${device}$SYSTEM_PART."
	PV_BIN=$(which pv 2>/dev/null)
	if [ $? -eq 0 ]; then
		pexec "${PV_BIN} \"${ISO_PATH}\" | dd of=\"${device}${SYSTEM_PART}\" bs=16M"
		if [ ${PIPESTATUS[0]} -ne 0 ]; then cleanup_and_exit 20; fi
		if [ $? -ne 0 ]; then cleanup_and_exit 21; fi
	else
		pexec dd if="${ISO_PATH}" of="${device}${SYSTEM_PART}"
		if [ $? -ne 0 ]; then cleanup_and_exit 22; fi
	fi

	einfo "Synchronizing caches"
	pexec sync

        einfo "ISO installed successfully."
}

function guess_data_part {
	local device
	device="$1"

	if [ -z "$DATA_FS"]; then DATA_FS="ext4"; fi

	GRUB_PART=$(guess_part "$device" "$DATA_FS")

	if [ $? -ne 0 ]; then
		eerror "Couldn't find any suitable partition on device ${device}."
		echo "       Either set the $$DATA_PART variable to the correct partition,"
		echo "       or create add an ext4 partition to the partition table,"
		echo "       or disable DATA installation."
		cleanup_and_exit 23
	else
		einfo "Using ${DATA_FS} partition ${device}${DATA_PART} as DATA partition"
	fi
}

function write_data {
	local device
	device="$1"

        if [ "${WRITE_DATA}" != "y" ]; then
                ewarn "DATA installation disabled."
                return
        fi

        if [ -z "$DATA_PART" ]; then
                ewarn "No DATA destination partition specified, will use the first mounted ext4 partition available on the device."
                guess_data_part "$device"
        fi

	mountpoint=$(grep "${device}${DATA_PART}" /proc/mounts | cut -d' ' -f2)

	einfo "Installing DATA in partition ${device}$DATA_PART."
	PV_BIN=$(which pv 2>/dev/null)
	if [ $? -eq 0 ]; then
		pexec "${PV_BIN} \"${DATA_PATH}\" | tar xJ -C \"${mountpoint}\""
		if [ ${PIPESTATUS[0]} -ne 0 ]; then cleanup_and_exit 24; fi
		if [ $? -ne 0 ]; then cleanup_and_exit 25; fi
	else
		pexec tar xf ${DATA_PATH} -C ${mountpoint}
		if [ $? -ne 0 ]; then cleanup_and_exit 26; fi
	fi

	einfo "Synchronizing caches"
	pexec sync

        einfo "DATA installed successfully."
}

function change_hostname {
	local device
	local mp
	device="$1"
	mp="$2"

	if [ -z "$DATA_HOSTNAME" ]; then
		DATA_HOSTNAME="ubuntu-$(date +%d-%m-%y_%H-%M)"
		ewarn "No hostname specified, using $DATA_HOSTNAME"
	fi
	einfo "Changing hostname to $DATA_HOSTNAME"
	echo "$DATA_HOSTNAME" > ${mp}/upper/etc/hostname
	sed "s|ubuntu|${DATA_HOSTNAME}|g" -i ${mp}/upper/etc/hosts
}

function configure_data {
	local device
	device="$1"

	if [ "${CONF_DATA}" != "y" ]; then
		ewarn "DATA configuration disabled."
		return
	fi

        if [ -z "$DATA_PART" ]; then
                ewarn "No DATA destination partition specified, will use the first mounted ext4 partition available on the device."
                guess_data_part "$device"
        fi

        mountpoint=$(grep "${device}${DATA_PART}" /proc/mounts | cut -d' ' -f2)

        einfo "Configuring DATA in partition ${device}$DATA_PART."
	change_hostname "$device" "$mountpoint"

	einfo "Synchronizing caches"
	pexec sync

	einfo "Configuration done"
}

function make_usb {
	local device
	device=$1

	wipe_parttable "$device"

	write_parttable "$device"

	make_filesystems "$device"

	mount_partitions "$device"

	setup_grub "$device"

	write_iso "$device"

	write_data "$device"

	configure_data "$device"

	cleanup_and_exit 0
}

## Get parameters ##

device="$1"


## $DEVICE checks ##

# Specified

if [ -z "$device" ]; then
	eerror "You must specify a device to use."
	eusage
	exit 1
fi

# File type

if [ -b "$device" ]; then
	einfo "$device is a block device."
elif [ -f "$device" ]; then
	einfo "$device is a regular file."
elif [ ! -e "$device" ]; then
	eerror "$device not found."
	exit 2
else
	eerror "$device is neither a block device nor a regular file."
	exit 3
fi

# Permissions

if [ ! -r "$device" ]; then
	eerror "$device is not readable."
	exit 4
elif [ ! -w "$device" ]; then
	eerror "$device is not writable."
	exit 5
else
	einfo "$device is readable/writable."
fi

## ISO check ##

if [ "$WRITE_ISO" == "y" ]; then
	# Specified

	if [ -z "$ISO_PATH" ]; then
	        eerror "You must set the ISO_PATH variable."
	        exit 51
	fi

	# File type

	if [ -b "$ISO_PATH" ]; then
	        einfo "$ISO_PATH is a block device."
	elif [ -f "$ISO_PATH" ]; then
	        einfo "$ISO_PATH is a regular file."
	elif [ ! -e "$ISO_PATH" ]; then
	        eerror "$ISO_PATH not found."
	        exit 52
	else
	        eerror "$ISO_PATH is neither a block device nor a regular file."
	        exit 53
	fi

	# Permissions

	if [ ! -r "$ISO_PATH" ]; then
	        eerror "$ISO_PATH is not readable."
	        exit 54
	else
	        einfo "$ISO_PATH is readable."
	fi
fi

## DATA check ##

if [ "$WRITE_DATA" == "y" ]; then
        # Specified

        if [ -z "$DATA_PATH" ]; then
                eerror "You must set the DATA_PATH variable."
                exit 55
        fi

        # File type

        if [ -f "$DATA_PATH" ]; then
                einfo "$DATA_PATH is a regular file."
        elif [ ! -e "$DATA_PATH" ]; then
                eerror "$DATA_PATH not found."
                exit 56
        else
                eerror "$DATA_PATH is not a regular file."
                exit 57
        fi

        # Permissions

        if [ ! -r "$DATA_PATH" ]; then
                eerror "$DATA_PATH is not readable."
                exit 58
        else
                einfo "$DATA_PATH is readable."
        fi
fi
		

# Partition table

einfo "$device partition table:"
pexec sfdisk -l $device
if [ $? -ne 0 ]; then
	exit 6
fi

ewarn "${CINV}$device WILL BE WIPED. ALL DATA WILL BE LOST.${CCLR}"
read -p "Do you want to continue? [y/N] " -r resp

case $resp in
	[yY][eE][sS]|[yY])
		echo ""
		for i in $(eval "echo {${WTIMEOUT}..0}");do echo -ne "$(einfo "Starting in: $i\r")" && sleep 1; done
		echo ""
		make_usb "$device"
	;;
	*)
		eerror "Aborted."
		exit 7
        ;;
esac
