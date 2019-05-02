#!/bin/bash
if [[ "$BASH_TRACE" ]]; then
    set -xv
    PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
fi


main() {
    prepare_git_user
    setup
    test_with_swcert
    test_with_pkcs11
}


setup() {
    export USERPIN=$PYKCS11PIN
    export PKCS11_CARD_DRIVER=$PYKCS11LIB
    run_as_pyff "/tests/test_setup_data.sh -d"
}


prepare_git_user() {
    echo 'Test setup 01: setup git user'
    cd /tmp
    git init # dummy repo
    git config --global user.email "tester@testinetics.com"
    git config --global user.name "Unit Test"
    git config --global push.default simple
}


run_as_pyff() {
    cmd=$1
    if (( $(id -u) == 0 )); then
        su --preserve-environment pyff -c "${cmd}"
    else
        $cmd
    fi

}


test_with_swcert() {
    echo; echo '=== test_pyff.sh (Aggregator) with SW-cert ==='
    export PIPELINEBATCH='/etc/pyff/md_swcert.fd'
    run_as_pyff /tests/test_pyff.sh

}


test_with_pkcs11() {
    echo; echo '=== start_pkcs11_services.sh ==='
    /scripts/start_pkcs11_services.sh


    if [[ "$SOFTHSM" ]]; then
        echo 'testing PKCS11 with SoftHSM'
        pytest --tb=short -o cache_dir=/tmp -m 'softhsm' /tests/test_pkcs11.py
        export PIPELINEBATCH=/etc/pyff/md_softhsm.fd
    else
        lsusb -v | grep "$PKCS11USBDEVICE" >/dev/null
        grep_rc=$?
        if (( grep_rc == 0 )); then
            echo "testing PKCS11 with $PKCS11USBDEVICE"
            if [[ "$PKCS11USBDEVICE"=='Nitro.Pro' ]]; then
                pytest --tb=short -o cache_dir=/tmp -m 'smartcard' /tests/test_pkcs11.py
                export PIPELINEBATCH=/etc/pyff/md_hsm_nitropro.fd
            else
                pytest --tb=short -o cache_dir=/tmp -m 'hsm' /tests/test_pkcs11.py
                export PIPELINEBATCH=/etc/pyff/md_hsm_etoken.fd
            fi
            echo; echo '=== test_pyff.sh (Aggregator) ==='
            run_as_pyff /tests/test_pyff.sh
        else
            echo; echo 'test PKCS11 failed: HSM USB Device $PKCS11USBDEVICE not found'
            exit 1
        fi
    fi

}


main $@
