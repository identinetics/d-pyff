#!/bin/bash

main() {
    create_sw_certificate_on_ramdisk
    fingerprint_cert
}


create_sw_certificate_on_ramdisk() {
    rm -f /ramdisk/*
    /scripts/x509_create_keys_on_disk.sh -n testcert \
        -s /C=AT/ST=Wien/L=Wien/O=TEST/OU=TEST/CN=testcert
    rc=$?
    if (( rc > 0 )); then
        echo "ERROR: Creating SW-cert failed with code=$rc" 1>2&
        exit 1
    fi
}

fingerprint_cert() {
    md5sum /ramdisk/testcert_crt.pem
}


main $@
