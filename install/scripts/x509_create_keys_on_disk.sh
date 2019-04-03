#!/usr/bin/env bash

main() {
    get_commandline_opts "$@"
    mount_ramdisk
    set_openssl_config
    create_keypair_and_certificate
    show_result
}


get_commandline_opts() {
    basicConstraintsCA='FALSE'
    keysize=2048
    x509subject='/C=AT/ST=Wien/L=Wien/O=Testfirma/OU=IT/CN=localhost'
    keyname='signer'
    while getopts ":ck:n:s:v" opt; do
      case $opt in
        c) basicConstraintsCA='TRUE';;
        k) keysize=$OPTARG
           re='^[0-9]{3,5}$'
           if ! [[ $OPTARG =~ $re ]] ; then
              echo "error: -k argument is not a number in the range from 1024 .. 16384" >&2; exit 1
           fi;;
        n) keyname=$OPTARG;;
        v) verbose="True";;
        s) x509subject=$OPTARG;;
        x) pkcs12="True";;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) usage; exit 0;;
      esac
    done
    #shift $((OPTIND-1))
}


usage() {
    cat << EOF
        Usage: $0 [-k <NNNN>] [-n <key name>] [-v] [-s <X509 subject>]
          -c  Use certificate as CA (basicConstraints:CA=TRUE)
          -h  print this help text
          -k  keysize (default: $keysize)
          -n  file name of key and certificate (default: $keyname)
          -v  verbose
          -s  x509 subject DN (default: $x509subject)

        Example:
           $0 -v -s "/C=AT/ST=Wien/L=Wien/O=Testfirma/OU=IT/CN=MDAGGR" -n mdaggr
EOF
}


mount_ramdisk() {
    if [[ ! $RAMDISKPATH ]]; then
        RAMDISKPATH="/ramdisk"
        df -Th | tail -n +2 | egrep "tmpfs|ramfs" | awk '{print $7}'| grep ${RAMDISKPATH} >/dev/null
        if (( $? != 0 )); then # ramfs not mounted at $RAMDISKPATH
            $sudo mkdir -p ${RAMDISKPATH}/ramdisk
            $sudo mount -t tmpfs -o size=1M tmpfs ${RAMDISKPATH}
            cd ${RAMDISKPATH}
            [[ $PWD != "$RAMDISKPATH" ]] && echo "could not make or mount ${RAMDISKPATH}" && exit 1
            echo "Created ramfs at ${RAMDISKPATH} (no size limit imposed - using up available RAM will freeze your system!)"
        else
            if [[ ! -z "$(ls -A $RAMDISKPATH)" ]]; then
                echo "Found key files - aborted. Delete contents of $RAMDISKPATH before creating new keys"
                exit 1
            fi
        fi
    fi
}


set_openssl_config() {
    cat > /tmp/openssl.cfg <<EOT
[req]
distinguished_name=dn
[ dn ]
[ ext ]
basicConstraints=CA:$basicConstraintsCA
EOT

}


create_keypair_and_certificate() {
    cmd1="openssl req
        -config /tmp/openssl.cfg
        -x509 -newkey rsa:${keysize}
        -keyout /ramdisk/${keyname}_key_pkcs8.pem
        -out /ramdisk/${keyname}_crt.pem
        -sha256 -days 3650 -nodes
        -batch -subj \"$x509subject\"
    "
    cmd2="openssl x509 -inform PEM -in /ramdisk/${keyname}_crt.pem -outform DER -out /ramdisk/${keyname}_crt.der"
    cmd3="openssl rsa -in /ramdisk/${keyname}_key_pkcs8.pem -out /ramdisk/${keyname}_key_pkcs1.pem"
    cmd4="openssl rsa -in /ramdisk/${keyname}_key_pkcs1.pem -outform DER -out /ramdisk/${keyname}_key.der"
    cmd5="openssl pkcs12 -export -out /ramdisk/${keyname}_crt.p12 -in /ramdisk/${keyname}_crt.pem -inkey /ramdisk/${keyname}_key_pkcs1.pem"

    if [ "$verbose" == "True" ]; then
        echo $cmd1
        echo $cmd2
        echo $cmd3
        echo $cmd4
        echo $cmd5
    fi

    tmpname=/tmp/$(basename $0.tmp)
    echo $cmd1 > $tmpname   # indirect execution as workaround against "invalid subject not beginning with '/'"
    bash $tmpname
    $cmd2
    $cmd3
    $cmd4
    chmod 600 /ramdisk/${keyname}_key*.pem \
              /ramdisk/${keyname}_key.der
    if [[ "$pkcs12" == 'True' ]]; then
        echo "create PKCS#12 certificate file including private key"
        $cmd5
        chmod 600 /ramdisk/${keyname}_crt.p12
    fi
}


show_result() {
    ls -l /ramdisk
}


main "$@"