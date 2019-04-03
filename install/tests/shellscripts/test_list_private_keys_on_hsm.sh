#!/bin/bash

pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --list-objects --type privkey \
        | grep 'Private Key Object'
if (( $? > 0 )); then
    echo " .. ERROR: No certificate found"
    exit 1
fi