#!/usr/bin/env bash
PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'

main() {
    printenv | sort
    echo
    setup
    run_tests
}


setup() {
    SCRIPT=$(basename $0)
    SCRIPT=${SCRIPT%.*}
    LOGDIR="/tmp/${SCRIPT%.*}"
    mkdir -p $LOGDIR
    LOGFILE="/tmp/${SCRIPT%.*}.log"
    echo "test_hsm_token.sh" > $LOGFILE
    echo "== Logfile: $LOGFILE"
    set +e
    [[ "$USERPIN" ]] || export USERPIN=$PYKCS11PIN
}


run_tests() {
    testid=10
    test_purpose='detect HSM USB device'
    test_cmd="lsusb -v | egrep $PKCS11USBDEVICE"
    log_test_header
    if [[ $SOFTHSM ]]; then
        log_newline " .. skipping, Soft HSM configured"
    else
        eval $test_cmd > $LOGDIR/test${testid}.log
        if (( $? != 0 )); then
            log_newline "\n  HSM USB device not found - failed HSM test"
            cat $LOGDIR/test${testid}.log | tee >> $LOGFILE
            exit 1
        else
            log_newline " .. OK"
        fi
    fi

    #=============
    testid=11
    test_purpose='PKCS11 driver lib, PYKCS11PIN'
    test_cmd='-z ${PYKCS11LIB+x}'
    log_test_header
    if [[ -z ${PYKCS11LIB+x} ]]; then
        die " .. ERROR: PYKCS11LIB not set - failed HSM test"
    else
        log_newline " .. OK"
    fi
    if [[ ! -e ${PYKCS11LIB} ]]; then
        die "PYKCS11LIB not found"
    fi
    if [[ -z ${PYKCS11PIN+x} ]]; then
        die "PYKCS11PIN not set - failed HSM test"
    fi


    #=============
    testid=12
    test_purpose='PCSCD running?'
    test_cmd='pidof /usr/sbin/pcscd'
    log_test_header
    if [[ $SOFTHSM ]]; then
        log_newline " .. Soft HSM  - no pcscd needed"
    else
        pid=$($test_cmd) > /dev/null
        if (( $? == 1 )); then
            (( $(id -u) == 0 )) || sudo='sudo'
            log_newline " .. not found; starting pcscd"
            $sudo /usr/sbin/pcscd
            sleep 1
            pid=$($test_cmd) > /dev/null
            if (( $? == 1 )); then
                log_newline " .. ERROR: pcscd process not running"
                exit 1
            fi
        else
            log_newline " .. OK"
        fi
    fi


    #=============
    testid=13
    test_purpose='HSM PKCS#11 device'
    test_cmd="pkcs11-tool --module $PYKCS11LIB --list-token-slots | grep ${PKCS11LIBDEVICE}"
    log_test_header
    pkcs11-tool --module $PYKCS11LIB --list-token-slots | grep $PKCS11LIBDEVICE 2>&1 \
        > $LOGDIR/test${testid}.log
    if (( $? > 0 )); then
        log_newline " .. ERROR: HSM Token not connected"
        cat $LOGDIR/test${testid}.log  | tee >> $LOGFILE
        exit 1
    else
        log_newline " .. OK"
    fi


    #=============
    testid=14
    test_purpose='Initializing HSM Token '
    test_cmd="pkcs11-tool --module $PYKCS11LIB --init-token --label mdsign --so-pin $SOPIN"
    log_test_header
    pkcs11-tool --module $PYKCS11LIB --init-token --label mdsign-token-citest --so-pin $SOPIN \
        > $LOGDIR/test${testid}.log 2>&1
    if (( $? > 0 )); then
        log_newline " .. ERROR: HSM Token not initialized, failed with code $?"
        cat $LOGDIR/test${testid}.log
        exit 1
    else
        log_newline " .. OK"
    fi


    #=============
    testid=15
    test_purpose='Initializing User PIN '
    test_cmd="pkcs11-tool --module $PYKCS11LIB --login --init-pin --pin $PYKCS11PIN --so-pin $SOPIN"
    log_test_header
    #pkcs11-tool --module $PYKCS11LIB --login --init-pin --pin $PYKCS11PIN --so-pin $SOPIN
    $test_cmd > $LOGDIR/test${testid}.log 2>&1
    if (( $? > 0 )); then
        log_newline " .. ERROR: User PIN not initialized, failed with code $?"
        cat $LOGDIR/test${testid}.log | tee >> $LOGFILE
        exit 1
    else
        log_newline " .. OK"
    fi


    #=============
    testid=15
    test_purpose='Login to HSM '
    test_cmd="pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --show-info"
    log_test_header
    pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --show-info 2>&1 \
        | grep 'present token' > $LOGDIR/test${testid}.log
    if (( $? > 0 )); then
        pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --show-info
        log_newline " .. ERROR: Login failed"
        cat $LOGDIR/${testid}.log
        exit 1
    else
        log_newline " .. OK"
    fi

    #=============
    testid=16
    test_purpose='create SW-certificate in ramdisk '
    test_cmd="/scripts/x509_create_keys_on_disk.sh -n testcert -s /C=AT/ST=Wien/L=Wien/O=TEST/OU=TEST/CN=testcert"
    log_test_header
    rm -f /ramdisk/*
    /scripts/x509_create_keys_on_disk.sh -n testcert \
        -s /C=AT/ST=Wien/L=Wien/O=TEST/OU=TEST/CN=testcert \
        > $LOGDIR/test${testid}.log 2>&1
    if (( $? > 0 )); then
        log_newline " .. ERROR: Creating SW-cert failed with code=$?"
        cat $LOGDIR/test${testid}a.log | tee >> $LOGFILE
        exit 1
    else
        log_newline " .. OK"
    fi

    #=============
    testid=17
    test_purpose='write certificate + private key to HSM '
    test_cmd="/scripts/pkcs11_key_to_token.sh -c /ramdisk/testcert_crt.der -k /ramdisk/testcert_key.der -l mdsign -n mdsign -s $SOPIN -t $PYKCS11PIN"
    log_test_header
    /scripts/pkcs11_key_to_token.sh -c /ramdisk/testcert_crt.der -k /ramdisk/testcert_key.der \
        -l sigkey-citest -n mdsign-token-citest -s $SOPIN -t $PYKCS11PIN > $LOGDIR/test${testid}.log 2>&1
    rc=$?
    if (( rc > 0 )); then
        log_newline " .. ERROR: Writing key and certificate to HSM token failed with code=${rc}"
        cat $LOGDIR/test${testid}b.log | tee >> $LOGFILE
        exit 1
    else
        log_newline " .. OK"
    fi


    #=============
    testid=18
    test_purpose='List certificate on HSM device: '
    test_cmd="pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --list-objects --type cert | grep 'Certificate Object'"
    log_test_header
    pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --list-objects --type cert \
        | grep 'Certificate Object' | perl -pe 'chomp' > $LOGDIR/test${testid}.log 2>&1
    if (( $? > 0 )); then
        die " .. ERROR: No certificate found"
    else
        log_newline " .. OK"
    fi


    #=============
    testid=19
    test_purpose='List private key on HSM device: '
    test_cmd="pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --list-objects --type privkey | grep 'Certificate Object'"
    log_test_header
    pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --list-objects --type privkey \
        | grep 'Private Key Object' | perl -pe 'chomp' > $LOGDIR/test${testid}.log 2>&1
    if (( $? > 0 )); then
        log_newline " .. ERROR: No private key found"
        cat $LOGDIR/test${testid}.log | tee >> $LOGFILE
        exit 1
    else
        log_newline " .. OK"
    fi

    #=============
    testid=20
    test_purpose='Sign test data '
    test_cmd="pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN --sign --input /tmp/bar --output /tmp/bar.sig"
    log_test_header
    if [[ $SOFTHSM ]]; then
        log_newline " .. skipping, SoftHSMv2 does not support signing"
    else
        log_newline "foo" > /tmp/bar
        pkcs11-tool --module $PYKCS11LIB --login --pin $PYKCS11PIN  \
            --sign --input /tmp/bar --output /tmp/bar.sig > $LOGDIR/test${testid}.log
        if (( $? > 0 )); then
            log_newline " .. ERROR: Signature failed"
            cat $LOGDIR/test${testid}.log | tee >> $LOGFILE
            exit 1
        else
            log_newline " .. OK"
        fi
    fi


    #=============
    testid=21
    test_purpose='Count objects using PyKCS11 '
    test_cmd="/tests/pykcs11_getkey.py --pin=$PYKCS11PIN --slot=0 --lib=$PYKCS11LIB | grep -a -c '=== Object '"
    log_test_header
    obj_count=$(/tests/pykcs11_getkey.py --pin=$PYKCS11PIN --slot=0 --lib=$PYKCS11LIB | grep -a -c '=== Object ')
    if (( $obj_count != 2 )); then
        die " .. ERROR: Expected 2 objects in HSM token, but listed ${obj_count}"
    else
        log_newline " .. OK"
    fi


    #=============
    testid=22
    test_purpose='List objects and PKCS11-URIs with p11tool '
    test_cmd="p11tool --provider $PYKCS11LIB --list-all --login pkcs11:"
    log_test_header
    export GNUTLS_PIN=$PYKCS11PIN
    p11tool --provider $PYKCS11LIB --list-all --login pkcs11: > $LOGDIR/test${testid}.log 2>&1
    obj_count=$(grep -c ^Object $LOGDIR/test${testid}.log)
    if (( $obj_count != 2 )); then
        die " .. ERROR: Expected 2 objects in HSM token, but listed ${obj_count}"
    else
        log_newline " .. OK"
    fi

    #=============
    testid=23
    test_purpose='List modules with p11.kit: '
    test_cmd="p11-kit list-modules"
    log_test_header
    printf "P11KIT_DESC=$P11KIT_DESC"
    [[ $P11KIT_DESC ]] || die 'ERROR: P11KIT_DESC not set'
    $test_cmd > $LOGDIR/test${testid}.log 2>&1
    obj_count=$(grep -c $P11KIT_DESC $LOGDIR/test${testid}.log)
    if (( $obj_count == 0 )); then
        die " .. ERROR: expected >=1 occurence(s) of '$P11KIT_DESC' in output of $test_cmd"
    else
        log_newline " .. OK"
    fi

    #=============
    testid=24
    test_purpose='openssl: create CSR'
    test_cmd="openssl req -keyform engine -engine pkcs11 -nodes -days -x509 -sha256 -out key.pem -subj '/C=AT/ST=vie/L=vie/O=acme/CN=testserver' -new -key 'pkcs11:token=test;object=mdsign;type=private;pin-value=$PYKCS11PIN'"
    log_test_header
    openssl req -keyform engine -engine pkcs11 -nodes -days -x509 -sha256 -out key.pem -subj '/C=AT/ST=vie/L=vie/O=acme/CN=testserver' -new -key "pkcs11:token=test;object=mdsign;type=private;pin-value=$PYKCS11PIN" \
        > $LOGDIR/test${testid}.log 2>&1
    rc=$?
    if (( $rc > 0 )); then
        log_newline " .. ERROR: Command returned $rc in $test_cmd"
        cat $LOGDIR/test${testid}.log | tee >> $LOGFILE
        exit 1
    else
        log_newline " .. OK"
    fi


    #=============
    testid=25
    test_purpose='openssl: create signature'
    test_cmd="openssl dgst -sha256 -sign 'pkcs11:token=test;object=mdsign;type=private;pin-value=$PYKCS11PIN' -keyform engine -engine pkcs11 -out /tmp/hosts.sig /etc/hosts"
    log_test_header
    openssl dgst -sha256 -sign "pkcs11:token=test;object=mdsign;type=private;pin-value=$PYKCS11PIN" -keyform engine -engine pkcs11 -out /tmp/hosts.sig /etc/hosts > $LOGDIR/test${testid}.log 2>&1
    rc=$?
    if (( $rc > 0 )); then
        log_newline " .. ERROR: Command returned $rc in $test_cmd"
        cat $LOGDIR/test${testid}.log | tee >> $LOGFILE
        exit 1
    else
        log_newline " .. OK"
    fi


    #=============
    testid=26
    test_purpose='openssl: verify signature'
    # openssl cannot work on x509 certs, needs raw pubkey
    openssl x509 -pubkey -noout -in /ramdisk/testcert_crt.pem > /ramdisk/testcert_pubkey.pem
    test_cmd="openssl dgst -sha256 -verify /ramdisk/testcert_pubkey.pem  -keyform PEM -signature hosts.sig /etc/hosts"
    log_test_header
    openssl dgst -sha256 -verify /ramdisk/testcert_pubkey.pem  -keyform PEM -signature /tmp/hosts.sig /etc/hosts > $LOGDIR/test${testid}.log 2>&1
    rc=$?
    if (( $rc > 0 )); then
        log_newline " .. ERROR: Command returned $rc in $test_cmd"
        cat $LOGDIR/test${testid}.log | tee >> $LOGFILE
        exit 1
    else
        log_newline " .. OK"
    fi


    #=============
    testid=27
    test_purpose='List objects with Java keytool '
    test_cmd="keytool -list -keystore NONE -storetype PKCS11 -storepass $PYKCS11PIN -providerClass sun.security.pkcs11.SunPKCS11 -providerArg /etc/pki/java/pkcs11.cfg"
    log_test_header
    # fit into single line:
    keytool -list -keystore NONE -storetype PKCS11 -storepass $PYKCS11PIN \
        -providerClass sun.security.pkcs11.SunPKCS11 -providerArg /etc/pki/java/pkcs11.cfg \
         > $LOGDIR/test${testid}.log 2>&1
    rc=$?
    if (( $rc > 0 )); then
        log_newline " .. ERROR: Command returned $rc in $test_cmd"
        cat $LOGDIR/test${testid}.log | tee >> $LOGFILE
        exit 1
    else
        entries=$(grep 'contains [[:digit:]]* entr' $LOGDIR/test${testid}.log)
        log_newline " .. OK ($entries)"
    fi


    #=============
    testid=28
    test_purpose='Create XML signature with xmlsectool'
    test_cmd="xmlsectool.sh --sign"
    log_test_header
    /opt/xmlsectool/xmlsectool.sh --sign --pkcs11Config /etc/pki/java/pkcs11.cfg --key mdsign \
         --keystoreProvider sun.security.pkcs11.SunPKCS11 \
         --keyPassword $PYKCS11PIN --inFile /tests/testdata/idpExampleCom.xml --outFile /tmp/idpExampleCom_signed.xml --verbose \
         > $LOGDIR/test${testid}.log 2>&1
    rc=$?
    if (( $rc > 0 )); then
        log_newline " .. ERROR: Command returned $rc in $test_cmd"
        cat $LOGDIR/test${testid}.log >> $LOGFILE
        cat $LOGDIR/test${testid}.log
        exit 1
    else
        log_newline " .. OK"
    fi


    #=============
    testid=29
    test_purpose='Verify XML signature with xmlsec1'
    test_cmd="xmlsec1 --verify"
    log_test_header
    /usr/bin/xmlsec1 --verify --pubkey-cert-pem /ramdisk/testcert_crt.pem  \
        --id-attr:ID urn:oasis:names:tc:SAML:2.0:metadata:EntitiesDescriptor \
        --output /tmp/idpExampleCom_verified.xml /tmp/idpExampleCom_signed.xml \
         > $LOGDIR/test${testid}.log 2>&1
    rc=$?
    if (( $rc > 0 )); then
        log_newline " .. ERROR: Command returned $rc in $test_cmd"
        cat $LOGDIR/test${testid}.log >> $LOGFILE
        cat $LOGDIR/test${testid}.log
        exit 1
    else
        log_newline " .. OK"
    fi
}



die() {
    echo "$@" 1>&2
    echo "$@" >> $LOGFILE
    exit 1
}


log_test_header() {
    printf "Test ${testid}: ${test_purpose} "
    echo "=======" >> $LOGFILE
    echo "Test ${testid}: ${test_purpose}" >> $LOGFILE
    echo "Command: ${test_cmd}" >> $LOGFILE
    printf "Result:" >> $LOGFILE
}


log_newline() {
    echo -e $1
    echo -e $1 >> $LOGFILE
}


log_no_newline() {
    printf $1
    printf $1 >> $LOGFILE
}


main $@
