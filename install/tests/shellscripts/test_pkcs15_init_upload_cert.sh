#!/bin/bash

main() {
    write_certificate_and_private_key_to_smartcard
}


write_certificate_and_private_key_to_smartcard() {
    /scripts/pkcs11_key_to_token.sh -c /ramdisk/testcert_crt.der -k /ramdisk/testcert_key.der \
        -l sigkey-citest -n mdsign-token-citest -s $SOPIN -t $PYKCS11PIN
    pkcs15-init --store-certificate /ramdisk/testcert_crt.pem --id 3 --so-pin $SOPIN  # default PIN=12345678
    pkcs15-init --store-private-key /ramdisk/testcert_key_pkcs8.pem --auth-id 3 --verify-pin --id 2 --so-pin $SOPIN
    rc=$?
    if (( rc > 0 )); then
        echo "ERROR: Writing key and certificate to HSM token failed. pkcs15-init returned $rc" 1>&2
        exit 1
    fi
}


main $@
