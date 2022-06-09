#!/usr/bin/env sh
# The new build.sh file for proper installation.
# The goal of this project is unlike the Potabi Build Tool
# Is to install the actual system. Initial tests of this
# tool is to follow various manual installation methods online,
# pick the best ones, and finally modify it to install a fully
# functional Potabi system.

# Temporary configs
export device="ada0"
export devdrive="/dev/${device}"
export install="/tmp/pool"
export hostname="experimental"

# build () {
# Replace existing drive
gpart destroy -F ${device}
gpart create -s gpt ${device}
gpart add -t freebsd-boot -s 128k -l boot ${device}
gpart add -t freebsd-zfs -l system ${device}
gpart bootcode -b /boot/pmbr -p /boot/gptzfsboot -i 1 ${device}

# Create mountpoint
mkdir -pv ${install}

# Create Zpool and mount
zpool create -fm ${install} zroot /dev/${device}p2
zpool set bootfs=zroot zroot
zfs set checksum=fletcher4 zroot
zfs set atime=off zroot
zfs set compression=gzip-6 zroot

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

# Add base items
chroot ${install} echo "hostname=\"${hostname}\"" >> /etc/rc.conf
chroot ${install} echo "zfs_enable=\"YES\"" >> /etc/rc.conf
chroot ${install} echo "ifconfig_re0=\"DHCP\"" >> /etc/rc.conf
chroot ${install} echo "zfs_load=\"YES\"" >> /boot/loader.conf
chroot ${install} echo "zfs.root.mountfrom=\"zfs:zroot\"" >> /boot/loader.conf
chroot ${install} ok unload
chroot ${install} ok load /boot/kernel/kernel
chroot ${install} ok load /boot/kernel/opensolaris.ko
chroot ${install} ok load /boot/kernel/zfs.ko
chroot ${install} ok set currdev="${device}p2"
chroot ${install} ok set vfs.root.mountfrom="zfs:zroot"
touch ${install}/etc/fstab
touch ${install}/etc/resolv.conf

# Sendmail
chroot ${install} `cd /etc/mail && make install`
chroot ${install} service sendmail onerestart

# Timezone
# skipped for now

# Move zpool mountpoint
zfs set mountpoint=legacy zroot
zfs set mountpoint=/home zroot/home
zfs set mountpoint=/tmp zroot/tmp
zfs set mountpoint=/usr zroot/usr
zfs set mountpoint=/var zroot/var

# Create entropy / Extra config
chroot ${install} touch /boot/entropy
chroot ${install} echo "gop set 0" >> ${release}/boot/loader.rc.local
# }

# build