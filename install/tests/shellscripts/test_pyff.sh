#!/usr/bin/env bash

main() {
    setup
    test_create_aggregate
    test_verify_metadata
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
    /scripts/pyff_aggregate.sh
    rc=$?
    if (( rc != 0 )); then
        echo 'Aggregator failed, skipping validation test'
        exit 1
    fi
    python /tests/check_metadata.py /var/md_feed/metadata.xml > $LOGDIR/test21.log
    /tests/assert_nodiff.sh $LOGDIR/test21.log /opt/testdata/results/$SCRIPT/test21.log
}


test_verify_metadata() {
    export LOGLEVEL=INFO
    /opt/xmlsectool-2/xmlsectool.sh --verifySignature --inFile /var/md_feed/metadata.xml \
        --certificate /etc/pki/sign/certs/metadata_crt.pem --whitelistDigest SHA-1 > $LOGDIR/test22.log
    rc=$?
    if (( rc != 0 )); then
        echo 'Metadata signature not valid'
        cat $LOGDIR/test22.log
        exit 2
    fi
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
