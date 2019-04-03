#!/bin/bash

if [[ $SOFTHSM ]]; then
    log_newline " .. skipping, Soft HSM configured"
else
    lsusb | grep "$HSMUSBDEVICE"
    if (( $? != 0 )); then
        echo "\n  HSM USB device not found - failed HSM test" 1>&2
        exit 1
    fi
fi
