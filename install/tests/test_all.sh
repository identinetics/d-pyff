#!/usr/bin/env bash

main() {
    setup
    test_with_swcert
    test_with_pkcs11
}


setup() {
    export USERPIN=$PYKCS11PIN
    export PKCS11_CARD_DRIVER=$PYKCS11LIB
    echo '=== setup test fixture (replace existing data and configuration) ==='
    /tests/test_setup_data.sh -d
}


test_with_swcert() {
    echo; echo '=== test_pyff.sh (Aggregator) with SW-cert ==='
    export PIPELINEBATCH='/etc/pyff/md_swcert.fd'
    /tests/test_pyff.sh

}


test_with_pkcs11() {
    echo; echo '=== start_pkcs11_services.sh ==='
    /scripts/start_pkcs11_services.sh
    lsusb | grep "$HSMUSBDEVICE"
    grep_rc = $?
    if [[ "$SOFTHSM" ]]; then
        export PIPELINEBATCH='/etc/pyff/md_softhsm.fd'
    elif (( grep_rc == 0 )); then
        export PIPELINEBATCH='/etc/pyff/md_hsm_eToken.fd'
    else
        echo; echo 'test PKCS11 failed: HSM USB Device $HSMUSBDEVICE not found'
        exit 1
    fi
    echo '=== test PKCS11 ==='
    pytest /tests/test_pkcs11.py
    echo; echo '=== test_pyff.sh (Aggregator) ==='
    /tests/test_pyff.sh
}


main $@
