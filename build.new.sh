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
export install="/mnt/install"

build () {
    # Replace existing drive
    gpart destroy -F ${device}
    gpart create -s gpt ${device}
    
    # Create mountpoint
    mkdir -pv ${install}

    # Create Zpool and mount
    zpool create potabi /dev/${device}
    zfs set mountpoint=${install} potabi 
    zfs set compression=gzip-6 potabi

    # Extract base/kernel tars
    tar -zxvf /usr/local/potabi/base.txz -C ${install}
    tar -zxvf /usr/local/potabi/kernel.txz -C ${install}

    # Add base items
    touch ${install}/etc/fstab
    mkdir -pv ${install}/cdrom
    
    # Create entropy / Extra config
    chroot ${install} touch /boot/entropy
    chroot ${install} echo "gop set 0" >> ${release}/boot/loader.rc.local

    # Snapshot and mount
    zfs snapshot potabi@clean
    zfs send -c -e potabi@clean | dd of=/dev/${device} status=progress bs=1M
}

build