#!/bin/bash

main() {
    fingerprint_cert
    write_certificate_and_private_key_to_hsm
}


write_certificate_and_private_key_to_hsm() {
    /scripts/pkcs11_key_to_token.sh -c /ramdisk/testcert_crt.der -k /ramdisk/testcert_key.der \
        -l sigkey -n mdsign-token-citest -s $SOPIN -t $PYKCS11PIN
    rc=$?
    if (( rc > 0 )); then
        echo "ERROR: Writing key and certificate to HSM token failed with code=$rc" 1>&2
        exit 1
    fi
}


fingerprint_cert() {
    md5sum /ramdisk/testcert_crt.pem # assuming .pem and .der match
}


main $@
