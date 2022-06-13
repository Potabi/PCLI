install_potabi-installer(){
    cp ${sftdir}/pkg/pc-sysinstall-2021041900,1.pkg ${install}/usr/local/tmp/pc-sysinstall-2021041900,1.pkg
    cp ${sftdir}/pkg/potabi-installer-ptbi.9.6.pkg ${install}/usr/local/tmp/potabi-installer-ptbi.9.6.pkg

    chroot ${install} pkg install -y /usr/local/tmp/pc-sysinstall-2021041900,1.pkg
    chroot ${install} pkg install -y /usr/local/tmp/potabi-installer-ptbi.9.6.pkg
}
