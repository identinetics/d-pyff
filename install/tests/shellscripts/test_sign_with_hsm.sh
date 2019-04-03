#!/bin/bash

if [[ $SOFTHSM ]]; then
    echo " .. skipping, SoftHSMv2 does not support signing"
else
    echo "foo" > /tmp/bar
    pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN  \
        --sign --input /tmp/bar --output /tmp/bar.sig
    if (( $? > 0 )); then
        echo "ERROR: Signature failed"
        exit 1
    fi
fi
