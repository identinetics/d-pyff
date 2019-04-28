#!/usr/bin/env bash
#

[ -z "$USERPIN" ] && USERPIN=Secret.1
[ -z "$SOPIN" ] && SOPIN=Secret.2
echo 'Initializing Token'
pkcs11-tool --module $PKCS11_CARD_DRIVER --init-token --label -l mdsign-token-citest --so-pin $SOPIN || exit -1

echo 'Initializing User PIN'
pkcs11-tool --module $PKCS11_CARD_DRIVER --login --init-pin --pin $USERPIN --so-pin $SOPIN

echo 'Generating RSA key'
pkcs11-tool --module $PKCS11_CARD_DRIVER --login --keypairgen --key-type rsa:2048 -d 1 --label sigkey-citest --pin $USERPIN || exit -1

echo 'Checking objects on card'
pkcs11-tool --module $PKCS11_CARD_DRIVER --login -O --pin $USERPIN || exit -1
