#!/bin/bash

echo "foo" > /tmp/bar
pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN  \
    --sign --mechanism SHA256-RSA-PKCS-PSS --input /tmp/bar --output /tmp/bar.sig
if (( $? > 0 )); then
    echo "ERROR: Signature failed"
    exit 1
fi
