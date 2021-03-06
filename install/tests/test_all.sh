#!/bin/bash

main() {
    setup
    test_with_swcert
    test_with_pkcs11
}


setup() {
    export USERPIN=$PYKCS11PIN
    export PKCS11_CARD_DRIVER=$PYKCS11LIB
    run_as_pyff "/tests/test_setup_data.sh -d"
}


test_with_swcert() {
    echo; echo '=== test_pyff.sh (Aggregator) with SW-cert ==='
    export PIPELINEBATCH='/etc/pyff/md_swcert.fd'
    run_as_pyff /tests/shellscripts/test_pyff.sh
}


test_with_pkcs11() {
    echo; echo '=== start_pkcs11_services.sh ==='
    /scripts/start_pkcs11_services.sh


    if [[ "$SOFTHSM" ]]; then
        echo 'testing PKCS11 with SoftHSM'
        export PIPELINEBATCH=/etc/pyff/md_softhsm.fd
        pytest --tb=short -o cache_dir=/tmp -m 'softhsm' /tests/test_pkcs11.py
    else
        lsusb -v | grep "$PKCS11USBDEVICE" >/dev/null
        grep_rc=$?
        if (( grep_rc == 0 )); then
            echo "testing PKCS11 with $PKCS11USBDEVICE"
            if [[ "$PKCS11LIBDEVICE" =~ 'Nitro.Pro' ]]; then
                export PIPELINEBATCH=/etc/pyff/md_hsm_nitropro.fd
                pytest --tb=short -o cache_dir=/tmp -m 'sc_nitrokeypro' /tests/test_pkcs11.py
                rc=$?
            elif [[ "$PKCS11LIBDEVICE" =~ 'Nitrokey.HSM' ]]; then
                export PIPELINEBATCH=/etc/pyff/md_hsm_etoken.fd
                pytest --tb=short -o cache_dir=/tmp -m 'hsm_nitro' /tests/test_pkcs11.py
                rc=$?
            elif [[ "$PKCS11LIBDEVICE" =~ 'eToken.5110' ]]; then
                export PIPELINEBATCH=/etc/pyff/md_hsm_etoken.fd
                pytest --tb=short -o cache_dir=/tmp -m 'hsm_etoken' /tests/test_pkcs11.py
                rc=$?
            fi
            if (( rc != 0 )); then
                echo ">>  test failed, test_pkcs11.py returned ${rc}"
                exit $rc
            fi
        else
            echo; echo '>>  test PKCS11 failed: HSM USB Device $PKCS11USBDEVICE not found'
            exit 1
        fi
    fi

}


run_as_pyff() {
    cmd=$1
    if (( $(id -u) == 0 )); then
        # to return the nested command's code print it a integer to stdout
        rc=$(su --preserve-environment "-c ${cmd}" pyff >/dev/null 2>&1; echo $?)
        return $rc
    else
        $cmd
        return $rc
    fi
}


if [[ "$BASH_TRACE" ]]; then
    set -xv
    PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
fi

main $@
