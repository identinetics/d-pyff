#!/bin/bash

export GNUTLS_PIN=$PYKCS11PIN
export GNUTLS_SO_PIN=$SOPIN
p11tool --provider $PYKCS11LIB --list-all --login pkcs11: > $LOGDIR/test${testid}.log 2>&1
obj_count=$(grep -c ^Object $LOGDIR/test${testid}.log)
if (( $obj_count != 2 )); then
    echo " .. ERROR: Expected 2 objects in HSM token, but listed ${obj_count}"
    exit 1
else
    log_newline " .. OK"
fi
