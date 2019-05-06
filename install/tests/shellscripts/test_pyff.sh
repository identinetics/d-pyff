#!/usr/bin/env bash

main() {
    setup
    test_create_aggregate
    test_entities_in_metadata
    test_verify_metadata_signature
    #test23
}


setup() {
    SCRIPT=$(basename $0)
    SCRIPT=${SCRIPT%.*}
    LOGDIR="/tmp/${SCRIPT%.*}"
    mkdir -p $LOGDIR
    echo "    Logfiles in $LOGDIR"
}


test_create_aggregate() {
    #run_as_pyff /scripts/pyff_aggregate.sh
    echo 'test_create_aggregate'
    rm -f /var/md_feed/metadata.xml
    eval /scripts/pyff_aggregate.sh
    rc=$?
    if (( rc != 0 )); then
        echo ">>  Aggregator failed, pyff_aggregate returned ${rc}"
        exit 1
    fi
}


test_entities_in_metadata() {
    ls -l /var/md_feed/metadata.xml
    python3 /tests/check_metadata.py /var/md_feed/metadata.xml | sort > $LOGDIR/test_cre_agg.log 2>&1
    /tests/assert_nodiff.sh $LOGDIR/test_cre_agg.log /opt/testdata/results/$SCRIPT/test_cre_agg.log
    rc=$?
    if (( rc != 0 )); then
        echo ">>  test failed, check_metadata returned ${rc}"
        exit $rc
    fi
}


test_verify_metadata_signature() {
    export LOGLEVEL=INFO
    fingerprint_cert
    /opt/xmlsectool-2/xmlsectool.sh --verifySignature --inFile /var/md_feed/metadata.xml \
        --certificate /ramdisk/testcert_crt.pem > $LOGDIR/test_verify_md.log
    rc=$?
    if (( rc != 0 )); then
        echo '>>  Metadata signature not valid'
        cat $LOGDIR/test_verify_md.log
        exit 2
    fi
}


fingerprint_cert() {
    md5sum /ramdisk/testcert_crt.pem
}


#test23() {
#    echo "Test 23: create aggregate from test data + push git repo. Pipeline: ${PIPELINEBATCH}"
#    /scripts/pyff_aggregate.sh -g
#}


if [[ "$BASH_TRACE" ]]; then
    set -xv
    PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
fi

main $@
