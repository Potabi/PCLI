#!/bin/sh
set -e -u 

# Run script as root
if [ "$(id -u)" != "0" ]; then
    echo "This script must be run as root"
    exit 1
fi

export cwd="`realpath | sed 's|/scripts||g'`"

. ${cwd}/conf/build.conf
. ${cwd}/conf/general.conf
. ${cwd}/conf/install.conf

cleanup(){
    umount ${release} || true
    umount ${release}/dev || true
    umount ${release}/var/cache/pkg/ || true
    mdconfig -d -u 0 || true
    rm -rf ${livecd}/pool.img || true
    rm -rf ${livecd} || true
}

setup(){
    # Make directories
    mkdir -pv ${livecd} ${base} ${iso} ${software} ${base} ${release} ${cdroot}

    # Create and mount pool
    zpool create potabi /dev/${device}
    zfs set mountpoint=${release} potabi 
    zfs set compression=gzip-6 potabi
}

build(){
    # Base Preconfig
    mkdir -pv ${release}/etc
    
    # Add and extract base/kernel into ${release}
    cd ${base}
    # TODO: Switch with CoreNGS release
    tar -zxvf /usr/local/potabi/base.txz -C ${release}
    tar -zxvf /usr/local/potabi/kernel.txz -C ${release}

    # Add base items
    touch ${release}/etc/fstab
    mkdir -pv ${release}/cdrom

    # Add packages
    cp /etc/resolv.conf ${release}/etc/resolv.conf
    mkdir -pv ${release}/var/cache/pkg
    mount_nullfs ${software} ${release}/var/cache/pkg
    mount -t devfs devfs ${release}/dev
    cat ${pkgdir}/${tag}.${desktop}.${platform} | xargs pkg -c ${release} install -y
    chroot ${release} pkg install -y pkg
    
    # Add software overlays 
    mkdir -pv ${release}/usr/local/general ${release}/usr/local/potabi
    
    . ${srcdir}/software.sh 
    setup_software

    rm ${release}/etc/resolv.conf
    umount ${release}/var/cache/pkg

    # Move source files
    cp /usr/local/potabi/base.txz ${release}/usr/local/potabi/base.txz
    cp /usr/local/potabi/kernel.txz ${release}/usr/local/potabi/kernel.txz
    
    # rc
    . ${srcdir}/setuprc.sh
    setuprc

    # Add live user
    chroot ${release} pw useradd ${liveuser} \
    -c "Potabi Live User" -d "/usr/home/${liveuser}"\
    -g wheel -G operator -m -s /bin/tcsh -k /usr/share/skel -w none

    mkdir -pv ${release}/home/${liveuser}/Desktop ${release}/home/${liveuser}/Documents ${release}/home/${liveuser}/Downloads ${release}/home/${liveuser}/Music ${release}/home/${liveuser}/Pictures ${release}/home/${liveuser}/Projects ${release}/home/${liveuser}/Videos

    # Other configs
    # mv ${release}/usr/local/etc/devd/automount_devd.conf ${release}/usr/local/etc/devd/automount_devd.conf.skip
    chroot ${release} touch /boot/entropy

    # Add desktop environment
    sed -i '' "s@#greeter-session=example-gtk-gnome@greeter-session=slick-greeter@" ${release}/usr/local/etc/lightdm/lightdm.conf
    
    if [ "${desktop}" == "lumina" ] ; then
        sed -i '' "s@#user-session=default@user-session=lumina@" ${release}/usr/local/etc/lightdm/lightdm.conf
    elif [ "${desktop}" == "xfce" ] ; then
        sed -i '' "s@#user-session=default@user-session=xfce@" ${release}/usr/local/etc/lightdm/lightdm.conf
    elif [ "${desktop}" == "cinnamon" ] ; then
        sed -i '' "s@#user-session=default@user-session=cinnamon@" ${release}/usr/local/etc/lightdm/lightdm.conf
    fi

    if [ "${desktop}" == "lumina" ] ; then
        echo "exec ck-launch-session start-lumina-desktop" >> ${release}/usr/home/${liveuser}/.xinitrc
        echo "exec ck-launch-session start-lumina-desktop" >> ${release}/root/.xinitrc
    elif [ "${desktop}" == "xfce" ] ; then
        echo "exec ck-launch-session startxfce4" >> ${release}/home/${liveuser}/.xinitrc
        echo "exec ck-launch-session startxfce4" >> ${release}/root/.xinitrc
    elif [ "${desktop}" == "cinnamon" ] ; then
        echo "exec ck-launch-session cinnamon-session" >> ${release}/home/${liveuser}/.xinitrc
        echo "exec ck-launch-session cinnamon-session" >> ${release}/root/.xinitrc
    fi

    # Extra configuration (borrowed from GhostBSD builder)
    echo "gop set 0" >> ${release}/boot/loader.rc.local

    # This sucks, but it has to function like this if we don't want it to break all the time
    echo "Unmounting ${release}/dev - this could take up to 60 seconds"
    umount ${release}/dev || true
    timer=0
    while [ "$timer" -lt 5000000 ]; do
        timer=$(($timer+1))
    done
    umount -f ${release}/dev || true

    # Uzip Ramdisk and Boot code borrowed from GhostBSD
    # Uzips
    install -o root -g wheel -m 755 -d "${cdroot}"
    mkdir -pv "${cdroot}/data"
    zfs snapshot potabi@clean
    zfs send -c -e potabi@clean | dd of=/usr/local/potabi-build/cdroot/data/system.img status=progress bs=1M

    # Boot
    cd ${release}
    tar -cf - boot | tar -xf - -C ${cdroot}
    echo "Boot directory listed as: ${boodir}"
    echo "CDRoot directory listed as: ${cdroot}"
    cp -r ${boodir}/* ${cdroot}/boot/.
    mkdir -pv ${cdroot}/etc
    cd ${prjdir} && zpool export potabi && while zpool status potabi >/dev/null; do :; done 2>/dev/null
}

cleanup
setup
build
