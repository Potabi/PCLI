# Ion is the OFFICIAL shell for Potabi Systems
# Beta-4 1.0A and later.
install_ion(){
    cd ${install}/usr/local/tmp
    fetch https://gitlab.redox-os.org/redox-os/ion/-/archive/master/ion-master.tar.gz
    tar xf ion-master.tar.gz
    cd ${install}/usr/local/tmp/ion-master 
    chroot ${install} make RUSTUP=0
    chroot ${install} make install prefix=/usr
    chroot ${install} make update-shells prefix=/usr
}