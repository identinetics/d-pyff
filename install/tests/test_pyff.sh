#!/usr/bin/env bash

SCRIPT=$(basename $0)
SCRIPT=${SCRIPT%.*}
LOGDIR="/tmp/${SCRIPT%.*}"
mkdir -p $LOGDIR
echo "    Logfiles in $LOGDIR"

set -e

# test 21
echo "Test 21: create aggregate from test data. Pipeline: ${PIPELINEBATCH}"
/scripts/pyff_aggregate.sh
python /tests/check_metadata.py /var/md_feed/metadata.xml > $LOGDIR/test21.log
/tests/assert_nodiff.sh $LOGDIR/test21.log /opt/testdata/results/$SCRIPT/test21.log


# test 22
echo 'Test 22: verify metadata signature with xmlsectool'
export LOGLEVEL=INFO
/opt/xmlsectool-2/xmlsectool.sh --verifySignature --inFile /var/md_feed/metadata.xml \
    --certificate /etc/pki/sign/certs/metadata_crt.pem --whitelistDigest SHA-1 > $LOGDIR/test22.log
if (( $? != 0 )); then
    echo 'Metadata signature not valid'
    cat $LOGDIR/test22.log
    exit 1
fi


# test 23
echo "Test 23: create aggregate from test data + push git repo. Pipeline: ${PIPELINEBATCH}"
/scripts/pyff_aggregate.sh

