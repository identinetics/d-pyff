#!/usr/bin/env bash

HSMUSBDEVICE='Aladdin Knowledge Systems Token JC'  # output of lsusb
HSMP11DEVICE='eToken 5110'                         # output of pkcs11-tool --list-token-slots

SCRIPT=$(basename $0)
SCRIPT=${SCRIPT%.*}
LOGDIR="/tmp/${SCRIPT%.*}"
mkdir -p $LOGDIR
echo "    Logfiles in $LOGDIR"
set +e

echo 'Test 30: HSM USB device'
lsusb | grep "$HSMUSBDEVICE" > $LOGDIR/test30.log
if (( $? != 0 )); then
    echo 'HSM USB device not found - failed HSM test'
    exit 1
fi


echo 'Test 31: PKCS11 driver lib'
if [[ -z ${PKCS11_CARD_DRIVER+x} ]]; then
    echo 'PKCS11_CARD_DRIVER not set - failed HSM test'
    exit 1
fi


if [[ ! -e ${PKCS11_CARD_DRIVER} ]]; then
    echo 'PKCS11_CARD_DRIVER not found'
    exit 1
fi


if [[ -z ${USERPIN+x} ]]; then
    echo 'USERPIN not set - failed HSM test'
    exit 1
fi


echo 'Test 32: PCSCD'
pid=$(pidof /usr/sbin/pcscd) > /dev/null
if (( $? == 1 )); then
    echo 'pcscd process not running'
    exit 1
fi


echo 'Test 33: HSM PKCS#11 device'
pkcs11-tool --module $PKCS11_CARD_DRIVER --list-token-slots | grep "$HSMP11DEVICE"  > $LOGDIR/test33.log
if (( $? > 0 )); then
    echo 'HSM Token not connected'
    exit 1
fi


echo 'Test 34: Login to HSM'
pkcs11-tool --module $PKCS11_CARD_DRIVER --login --pin $USERPIN --show-info 2>&1 \
    | grep 'present token'  > $LOGDIR/test34.log
if (( $? > 0 )); then
    pkcs11-tool --module $PKCS11_CARD_DRIVER --login --pin $USERPIN --show-info
    echo 'Login failed'
    exit 1
fi


echo 'Test 35: List certificate(s)'
pkcs11-tool --module $PKCS11_CARD_DRIVER --login --pin $USERPIN --list-objects  --type cert 2>&1 \
    | grep 'Certificate Object'  > $LOGDIR/test35.log
if (( $? > 0 )); then
    echo 'No certificate found'
    exit 1
fi


echo 'Test 36: List private key(s)'
pkcs11-tool --module $PKCS11_CARD_DRIVER --login --pin $USERPIN --list-objects  --type privkey 2>&1 \
    | grep 'Private Key Object'  > $LOGDIR/test36.log
if (( $? > 0 )); then
    echo 'No private key found'
    exit 1
fi


echo 'Test 37: Sign test data'
echo "foo" > /tmp/bar
pkcs11-tool --module $PKCS11_CARD_DRIVER --login --pin $USERPIN  \
    --sign --input /tmp/bar --output /tmp/bar.sig  > $LOGDIR/test38.log 2>&1
if (( $? > 0 )); then
    echo 'Signature failed'
    exit 1
fi


echo 'Test 38: Count objects using PyKCS11'

/tests/pykcs11_getkey.py --pin=$USERPIN --slot=0 --lib=$PKCS11_CARD_DRIVER 2>&1 \
    | grep -a -c '=== Object '  > $LOGDIR/test38.log
if (( $? > 0 )); then
    echo 'Listing HSM token object with PyKCS11 lib failed'
    exit 1
fi