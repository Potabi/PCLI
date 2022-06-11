#!/usr/bin/env sh
# The new build.sh file for proper installation.
# The goal of this project is unlike the Potabi Build Tool
# Is to install the actual system. Initial tests of this
# tool is to follow various manual installation methods online,
# pick the best ones, and finally modify it to install a fully
# functional Potabi system.

set -e # Kill on error

# Temporary configs
export device="ada0"
export devdrive="/dev/${device}"
export install="/tmp/pool"
export hostname="experimental"

# build () {
# Replace existing drive
zpool destroy -f zroot || true
rm -rf ${install} || true
gpart destroy -F ${device} || true
gpart create -s gpt ${device}
gpart add -t freebsd-boot -s 500k -l boot ${device}
gpart add -t freebsd-zfs -l system ${device}
gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 ${device}

# Create mountpoint
mkdir -pv ${install}

# Create Zpool and mount
zpool create -fm ${install} zroot /dev/${device}p2
zpool set bootfs=zroot zroot
zfs set checksum=fletcher4 zroot
zfs set atime=off zroot
zfs set compression=lz4 zroot

# ZFS Create
zfs create -o exec=on -o setuid=off zroot/tmp
zfs create zroot/var
zfs create -o exec=on -o setuid=off zroot/var/tmp
zfs create zroot/usr
zfs create zroot/home
zfs create -o exec=off -o setuid=off zroot/var/empty
zfs create -o exec=off -o setuid=off zroot/var/run
chmod 1777 ${install}/var/tmp

# Extract base/kernel tars
tar -zxvf /usr/local/potabi/base.txz -C ${install}
tar -zxvf /usr/local/potabi/kernel.txz -C ${install}

ls ${install}

# Add base items
chroot ${install} echo "hostname=\"${hostname}\"" >> /etc/rc.conf
chroot ${install} echo "zfs_enable=\"YES\"" >> /etc/rc.conf
chroot ${install} echo "ifconfig_re0=\"DHCP\"" >> /etc/rc.conf
chroot ${install} echo "opensolaris_load=\"YES\"" >> /boot/loader.conf
chroot ${install} echo "zfs_load=\"YES\"" >> /boot/loader.conf
chroot ${install} echo "zfs.root.mountfrom=\"zfs:gpt/POTABI\"" >> /boot/loader.conf
# chroot ${install} ok unload
# chroot ${install} ok load /boot/kernel/kernel
# chroot ${install} ok load /boot/kernel/opensolaris.ko
# chroot ${install} ok load /boot/kernel/zfs.ko
# chroot ${install} ok set currdev="${device}p2"
# chroot ${install} ok set vfs.root.mountfrom="zfs:zroot"
touch ${install}/etc/fstab
touch ${install}/etc/resolv.conf

# Timezone
# skipped for now

# Create entropy / Extra config
gpart modify -i 1 -l "BOOT" ${device}
gpart modify -i 2 -l "POTABI" ${device}
chroot ${install} touch /boot/entropy
chroot ${install} echo "gop set 0" >> ${install}/boot/loader.rc.local
chroot ${install} echo "/dev/gpt/POTABI / zfs rw,noatime 0 0" > /etc/fstab

# Move zpool mountpoint
zfs unmount -a
zfs set mountpoint=legacy zroot
zfs set mountpoint=/home zroot/home
zfs set mountpoint=/tmp zroot/tmp
zfs set mountpoint=/usr zroot/usr
zfs set mountpoint=/var zroot/var

# Final steps
zpool import -f -o cachefile=/tmp/zpool.cache -o altroot=${install} zroot || true
cp /tmp/zpool.cache ${install}/boot/zfs/zpool.cache || true
zpool export zroot
zpool import zroot

# }

# build