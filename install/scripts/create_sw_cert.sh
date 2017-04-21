#!/usr/bin/env bash
set -e -o pipefail

# create a new signing certificate for the aggregator

main() {
    get_commandline_args
    set_openssl_config
    create_cert
    list_cert
}

get_commandline_args() {
    USAGE=$(printf "%s\n" \
        "usage: $0 [-h] [-p] <cn> " \
        "  -h  print this help text" \
        "  -p  print command") \
        "  <cn>  common name part of x509 subject"

    while getopts ":p" opt; do
      case $opt in
        p) PRINT="True";;
        *) echo $USAGE; exit 0;;
      esac
    done
    shift $((OPTIND-1))
    if [ -z $1 ]; then
        echo 'missing argument "common name"'
        echo $USAGE
        exit 1
    fi
    CommonName=$1
}


set_openssl_config() {
    cat > /tmp/openssl.cfg <<EOT
[req]
distinguished_name=dn
[ dn ]
[ ext ]
basicConstraints=CA:FALSE
EOT

}


create_cert() {
    cmd1="openssl req
        -config /tmp/openssl.cfg
        -x509 -newkey rsa:4096
        -keyout /etc/pki/sign/private/metadata_key_pkcs8.pem
        -out /etc/pki/sign/certs/metadata_crt.pem
        -sha256
        -days 3650 -nodes
        -batch -subj '/C=AT/ST=Wien/L=Wien/O=Bildungsministerium/OU=IT/CN=$CommonName'
    "
    # pyff requires the old pkcs1 private key format -> convert
    cmd2="openssl rsa -in /etc/pki/sign/private/metadata_key_pkcs8.pem
        -out /etc/pki/sign/private/metadata_key.pem
    "
    if [ "$PRINT" == "True" ]; then
        echo $cmd1 $cmd2"
    fi
    $cmd1
    $cmd2
    chmod 600 /etc/pki/sign/private/metadata_key*
}

list_cert() {
    openssl x509 -text -noout \
        -in /etc/pki/sign/certs/metadata_crt.pem \
        -certopt no_pubkey -certopt no_issuer -certopt no_sigdump
}


main