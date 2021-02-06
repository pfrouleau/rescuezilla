#!/bin/bash

# Only run if called from inside a VM
if [[ -z "$(dmidecode | grep -i "Product Name: VirtualBox")" ]]
then
    echo "WARNING: no VM detected!"
    echo "Refusing to run to avoid to corrupt the partitions"
    exit 1
fi >&2

# 2nd check to protect developer environment
if [[ $1 != "doit" ]]
then
    echo "WARNING! Magic keyword missing; aborting." >&2
    exit 42
fi

# Source: https://superuser.com/questions/332252/how-to-create-and-format-a-partition-using-a-bash-script
# to create the partitions programatically (rather than manually)
# we're going to simulate the manual input to fdisk
# The sed script strips off all the comments so that we can
# document what we're doing in-line with the actual commands
# Note that a blank line (commented as "defualt" will send a empty
# line terminated with a newline to take the fdisk default.
sed -e 's/\s*\([\+0-9a-zA-Z]*\).*/\1/' << EOF | fdisk /dev/sda
  o # clear the in memory partition table
  n # new partition
  p # primary partition
  1 # partition number 1
    # default - start at beginning of disk
  +100M # 100 MB boot partition
  n # new partition
  p # primary partition
  2 # partition number 2
    # default, start immediately after preceding partition
  +200M #
  n # new partition
  p # primary partition
  3 # partition number 3
    # default, start immediately after preceding partition
  +200M #
  t # change partition type
    # default, partition 3
  b # FAT32
  n # new partition
  e # extended partition, implicitly number 4
    # default, start immediately after the preceding partition
    # default, extend partition to end of disk
  n # new partition
    # default, start at the begining of the extended partition
  +200M #
  t # change partition type
    # default, partition 5
  7 # NTFS/ExFAT
  a # make a partition bootable
  1 # bootable partition is partition 1 -- /dev/sda1
  p # print the in-memory partition table
  w # write the partition table
  q # and we're done
EOF

partprobe

# Format the partitions

mkfs.ext2 -L BootExt2   /dev/sda1
mkfs.ext4 -L RootExt4   /dev/sda2
mkfs.vfat -n DATA_FAT32 /dev/sda3
mkfs.ntfs -L DATA_NTFS  /dev/sda5

# Copy some data in the partitions

mkdir -p dst
for p in 1 2 3 5
do
    mount /dev/sda$p dst &&
    rsync -aq /rofs/usr/bin dst/
    umount dst
done
rmdir dst
