#!/usr/bin/env bash

# This is a simplified approach to unit test. To avoid dependencies to test automation frameworks,
# the chosed approach is to stop testing at the first failure.

set -e

export USERPIN=$PYKCS11PIN
export PKCS11_CARD_DRIVER=$PYKCS11LIB

echo '=== test_setup_swcert.sh ==='
source /tests/test_setup_swcert.sh

#echo; echo '=== test_pyffd (MDX/DS) with swcert ==='
#export PIPELINEBATCH=/etc/pyff/md_swcert.fd
#export PIPELINEDAEMON=/etc/pyff/mdx_swcert.fd
#/tests/test_pyffd.sh

echo; echo '=== test_pyff.sh (Aggregator) with SW-cert ==='
export PIPELINEBATCH=/etc/pyff/md_swcert.fd
export PIPELINEDAEMON=/etc/pyff/mdx_swcert.fd
/tests/test_pyff.sh

echo; echo '=== start_pkcs11_services.sh ==='
/scripts/start_pkcs11_services.sh


HSMUSBDEVICE='Aladdin Knowledge Systems Token JC'  # output of lsusb
HSMP11DEVICE='eToken 5110'                         # output of pkcs11-tool --list-token-slots
set +e
lsusb | grep "$HSMUSBDEVICE"
rc=$?
set -e
if (( $rc > 0 )); then
    # echo; echo 'HSM USB Device $HSMUSBDEVICE not found'
    # exit 0
    echo '=== test_pyff.sh (Aggregator) with SoftHSM ==='
    export PIPELINEBATCH=/etc/pyff/md_softhsm.fd
    /tests/test_pyff.sh
    echo '=== All tests completed with SoftHSM ==='
else
    echo; echo '=== test_hsm_eToken.sh ==='
    /tests/test_hsm_eToken.sh
    echo; echo '=== test_pyff.sh (Aggregator) with HSM eToken ==='
    export PIPELINEBATCH=/etc/pyff/md_hsm_eToken.fd
    /tests/test_pyff.sh
    echo '=== All tests completed with eToken HSM ==='
fi

