#!/usr/bin/env bash

main() {
    start_pcscd
    test_carddriver_setting
    opensc_list_reades_and_drivers
    show_pkcs11_info
    run_pykcs11
    #show_pkcs15_objects
    exec bash
}


start_pcscd() {
    init_sudo
    if [[ "$OSTYPE" != darwin* ]]; then
        echo
        echo "=== Starting Smartcard Service ==="
        $sudo /usr/sbin/pcscd
    fi
}


init_sudo() {
    if [ $(id -u) -ne 0 ]; then
        sudo="sudo"
    fi
}


test_carddriver_setting() {
    if [[ -z "$PKCS11_CARD_DRIVER" ]]; then
        if [[ "$OSTYPE" == darwin* ]]; then
            PKCS11_CARD_DRIVER='/Library/Frameworks/eToken.framework/Versions/A/libeToken.dylib'
        else
            echo "Env variable PKCS11_CARD_DRIVER not set"
            exit 1
        fi
    fi
}


show_pkcs11_info() {
    [ -z "$USERPIN" ] && USERPIN='secret1'
    echo
    echo "=== show token info ==="
    pkcs11-tool --module $PKCS11_CARD_DRIVER --show-info
    echo
    echo "=== show token slots ==="
    pkcs11-tool --module $PKCS11_CARD_DRIVER --list-token-slots
    echo
    echo "=== show token objects ==="
    pkcs11-tool --module $PKCS11_CARD_DRIVER --list-objects --slot 0
    echo
    echo "=== login ==="
    pkcs11-tool --module $PKCS11_CARD_DRIVER --list-objects --slot 0 --login --pin $USERPIN
    echo
    echo "=== test keys ==="
    pkcs11-tool --module $PKCS11_CARD_DRIVER --list-objects --slot 0 --login --pin $USERPIN --test
}


run_pykcs11() {
    export PYKCS11LIB=$PKCS11_CARD_DRIVER
    SCRIPTDIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
    python3 /tests/pykcs11_getinfo.py -s 0 -m
}


show_pkcs15_objects() {
    echo
    echo "=== dump pkcs15 info ==="
    pkcs15-tool -D
}


opensc_list_reades_and_drivers() {
    echo
    echo "=== opensc list readers and drivers ==="
    opensc-tool --list-readers
    #opensc-tool --list-drivers
}

main
