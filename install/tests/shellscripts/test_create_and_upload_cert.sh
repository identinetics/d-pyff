#!/bin/bash


create_sw_certificate_on_ramdisk() {
    rm -f /ramdisk/*
    /scripts/x509_create_keys_on_disk.sh -n testcert \
        -s /C=AT/ST=Wien/L=Wien/O=TEST/OU=TEST/CN=testcert
    if (( $? > 0 )); then
        echo "ERROR: Creating SW-cert failed with code=$?" 1>2&
        exit 1
    fi
}

write_certificate_and_private_key_to_hsm() {
    /scripts/pkcs11_key_to_token.sh -c /ramdisk/testcert_crt.der -k /ramdisk/testcert_key.der \
        -l mdsign -n test -s $SOPIN -t $PYKCS11PIN
    if (( $? > 0 )); then
        echo "ERROR: Writing key and certificate to HSM token failed with code=$?" 1>&2
        exit 1
    fi
}


create_sw_certificate_on_ramdisk
write_certificate_and_private_key_to_hsm
