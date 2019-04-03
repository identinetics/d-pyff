#!/usr/bin/env bash

# assert that a file created in a test run is identical to reference data

TESTFILE=$1
REF_FILE=$2

diff --ignore-space-change $TESTFILE $REF_FILE
if (( $? != 0 )); then
    echo 'Output of test does not match expected value. Expected:'
    cat $REF_FILE
    echo 'Found:'
    cat $TESTFILE
    exit 1
fi



