install_doas(){
    mkdir -pv ${install}/usr/local/etc
    touch ${install}/usr/local/etc/doas.conf
    echo "permit nopass keepenv :wheel" >> ${install}/usr/local/etc/doas.conf
    echo "permit nopass keepenv root as root" >> ${install}/usr/local/etc/doas.conf
    ln ${install}/usr/local/bin/doas ${install}/usr/local/bin/sudo
    ln ${install}/usr/local/bin/doas ${install}/usr/local/bin/admin
    ln ${install}/usr/local/bin/doas ${install}/usr/local/bin/root
}