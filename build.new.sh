#!/usr/bin/env sh
# The new build.sh file for proper installation.
# The goal of this project is unlike the Potabi Build Tool
# Is to install the actual system. Initial tests of this
# tool is to follow various manual installation methods online,
# pick the best ones, and finally modify it to install a fully
# functional Potabi system.

set -e # Kill on error

# Temporary configs

export cwd="`realpath | sed 's|/scripts||g'`"

# . ${cwd}/conf/build.conf
# . ${cwd}/conf/general.conf
. ${cwd}/conf/install.conf

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
cp -vr /bin/ ${install}/bin || true
cp -vr /boot/ ${install}/boot || true
cp -vr /usr/ ${install}/usr || true
cp -vr /etc/ ${install}/etc || true
cp -vr /lib/ ${install}/lib || true
cp -vr /libexec/ ${install}/libexec || true
cp -vr /media/ ${install}/media || true
cp -vr /root/ ${install}/root || true
cp -vr /sbin/ ${install}/sbin || true
cp -vr /sys/ ${install}/sys || true
cp -vr /var/ ${install}/var || true

# Add base items
touch ${install}/etc/rc.conf || true
touch ${install}/boot/loader.conf || true 
# echo "hostname=\"${hostname}\"" >> ${install}/etc/rc.conf
# echo "zfs_enable=\"YES\"" >> ${install}/etc/rc.conf
# echo "ifconfig_re0=\"DHCP\"" >> ${install}/etc/rc.conf
# echo "sendmail_enable=\"NONE\"" >> ${install}/etc/rc.conf
echo "opensolaris_load=\"YES\"" >> ${install}/boot/loader.conf
echo "zfs_load=\"YES\"" >> ${install}/boot/loader.conf
echo "zfs.root.mountfrom=\"zfs:gpt/POTABI\"" >> ${install}/boot/loader.conf
echo "Displaying loader.conf and rc.conf"
cat ${install}/boot/loader.conf
cat ${install}/etc/rc.conf
touch ${install}/etc/fstab
touch ${install}/etc/resolv.conf

# Timezone
# skipped for now

# Sendmail 
chroot ${install} echo "`cd /etc/mail && make aliases`"

# Userspace
chroot ${release} pw useradd ${liveuser} \
-c ${username} -d "/usr/home/${liveuser}"\
-g wheel -G operator -m -s /bin/tcsh -k /usr/share/skel -w none
sed -i '' "s@#greeter-session=example-gtk-gnome@greeter-session=slick-greeter@" ${release}/usr/local/etc/lightdm/lightdm.conf
echo "exec ck-launch-session start-lumina-desktop" >> ${install}/usr/home/${liveuser}/.xinitrc
echo "exec ck-launch-session start-lumina-desktop" >> ${install}/root/.xinitrc

# Create entropy / Extra config
gpart modify -i 1 -l "BOOT" ${device}
gpart modify -i 2 -l "POTABI" ${device}
chroot ${install} touch /boot/entropy
chroot ${install} echo "gop set 0" >> ${install}/boot/loader.rc.local
chroot ${install} echo "/dev/gpt/POTABI / zfs rw,noatime 0 0" > /etc/fstab

# Move zpool mountpoint
zfs unmount ${install}
zfs set mountpoint=legacy zroot
zfs set mountpoint=/home zroot/home
zfs set mountpoint=/tmp zroot/tmp
zfs set mountpoint=/usr zroot/usr
zfs set mountpoint=/var zroot/var

# Final steps
zpool import -f -o cachefile=/tmp/zpool.cache -o altroot=${install} zroot || true
cp /tmp/zpool.cache ${install}/boot/zfs/zpool.cache || true
echo "############################################################"
echo "Install Completed!"
echo "############################################################"
zpool export zroot
zpool import zroot