#!/bin/bash

#set -euo pipefail

function list_disk(){
  echo "List Disks: "
  lsblk
}

function format_and_mount_disk_without_password (){

list_disk
read -r -p "Enter block device to install arch onto (press enter for default: nvme0n1): " BLOCK_DEVICE
BLOCK_DEVICE=${BLOCK_DEVICE:-nvme0n1}

dd if=/dev/zero of="/dev/${BLOCK_DEVICE}" bs=1M count=5000 status=progress

MEMORY_SIZE="$(grep MemTotal /proc/meminfo | awk '{print $2}')"

# https://superuser.com/questions/332252/how-to-create-and-format-a-partition-using-a-bash-script
# shellcheck disable=SC2086
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/${BLOCK_DEVICE}
  g # create new GPT partition table
  n # new partition
  1 # partition number 1
    # default - start at beginning of disk
  +2G # 2 GB boot parttion
  n # new partition
  2 # partition number 2
    # default - start at beginning of disk
  +${MEMORY_SIZE}K # same size as memory
  n # new partition
  3 # partition number 3
    # default, start immediately after preceding partition
    # default, extend partition to end of disk
  t # change boot partion type
  1 # EFI
  1 # EFI
  w # write the partition table
  q # quit
EOF

# shellcheck disable=SC2012 disable=SC2086
BOOT_PARTITION="$(ls /dev/${BLOCK_DEVICE}* | sed '2q;d' | sed 's#^/dev/##g')"
echo 'Boot Partition: '$BOOT_PARTITION''
# shellcheck disable=SC2012 disable=SC2086
SWAP_PARTITION="$(ls /dev/${BLOCK_DEVICE}* | sed '3q;d' | sed 's#^/dev/##g')"
echo 'SWAP Partition: '$SWAP_PARTITION''
# shellcheck disable=SC2012 disable=SC2086
ROOT_PARTITION="$(ls /dev/${BLOCK_DEVICE}* | sed '4q;d' | sed 's#^/dev/##g')"
echo 'ROOT Partition: '$ROOT_PARTITION''

#Format the partitions
#root
mkfs.ext4 "/dev/${ROOT_PARTITION}"
#swap
mkswap "/dev/${SWAP_PARTITION}"
#boot
mkfs.fat -F 32 "/dev/${BOOT_PARTITION}"

#Mount the file systems
#Mount the root volume to /mnt
mount "/dev/${ROOT_PARTITION}" /mnt
#For UEFI systems, mount the EFI boot system partition
mount --mkdir "/dev/${BOOT_PARTITION}" /mnt/boot
#enable swap with swapon
swapon "/dev/${SWAP_PARTITION}"

}

function main (){
  read -p "Do you want to auto formet and mount your disk? (yes/no): " choice

  case "$choice" in
    yes|YES|y|Y)
      format_and_mount_disk_without_password
      ;;
    no|NO|n|N)
      echo "Show your disk format and mount"
      list_disk
      ;;
    *)
      echo "Invalid choice"
      ;;
  esac
}

main
