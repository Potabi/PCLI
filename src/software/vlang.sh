install_vlang(){
    mkdir -pv ${install}/usr/local/generic/v
    git clone https://github.com/vlang/v ${install}/usr/local/generic/v/. --depth 1
    cd ${install}/usr/local/generic/v/
    make 
    chmod 775 ${install}/usr/local/generic/v/v 
    ln ${install}/usr/local/generic/v/v ${install}/bin/v
}