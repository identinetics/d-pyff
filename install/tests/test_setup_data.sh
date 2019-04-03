#!/usr/bin/env bash

main() {
    check_root
    get_commandline_opts
    setup_logging
    delete_exsting_data
    prepare_test_config_sw_cert
    prepare_git_user
    prepare_mdfeed_repo
    create_sw_signing_cert
    create_git_ssh_keys
}


check_root() {
    if (( $(id -u) == 0 )); then
        echo 'setup is not supposed to be run with root privileges'
        exit 1
    fi
}


get_commandline_opts() {
    while getopts ":d" opt; do
      case $opt in
        d) deleteopt=1;;
        *) echo "usage from shell: $0 [-d]
             -d  delete previous data
           "; exit 0;;
      esac
    done
    shift $((OPTIND-1))
}


setup_logging() {
    SCRIPT=$(basename $0)
    SCRIPT=${SCRIPT%.*}
    LOGDIR="/tmp/${SCRIPT%.*}"
    mkdir -p $LOGDIR
    echo "    Logfiles in $LOGDIR"
    export LOGLEVEL=INFO
}


delete_exsting_data() {
    if [[ "$deleteopt" ]]; then
        echo 'Test setup: remove existing data'
        rm -f /etc/pyff/*.fd
        rm -rf /etc/pki/sign/*
        rm -rf /var/md_source/*
        rm -f /etc/pki/sign/*/metadata*
        rm -f /home/pyff/.ssh/id_ed25519_*
        rm -rf /var/md_feed/.git
    fi
}


prepare_test_config_sw_cert() {
    echo 'Test setup 01: set test config and add metadata source data (not overwriting existing data)'
    cp -np  /opt/testdata/etc/pki/tls/openssl.cnf /etc/pki/tls/
    cp -np  /opt/testdata/etc/pyff/* /etc/pyff/
    cp -npr /opt/testdata/md_source/*.xml /var/md_source/
    #cp -pr /opt/testdata/etc/pki/sign/* /etc/pki/sign/  created in test 04
    cp -pr /opt/testdata/etc/pyff/* /etc/pyff/
    cp -pr /opt/testdata/md_source/* /var/md_source/

}


prepare_git_user() {
    echo 'Test setup 02: setup git user'
    git config --global user.email "tester@testinetics.com"
    git config --global user.name "Unit Test"
    git config --global push.default simple
}


prepare_mdfeed_repo() {
    echo 'Test setup 03: create local mdfeed repo'
    cd /var/md_feed
    git init > $LOGDIR/prepare_mdfeed_repo.log
    git add --all >> $LOGDIR/prepare_mdfeed_repo.log
    touch .gitignore
    git add .gitignore
    git commit -m 'empty' >> $LOGDIR/prepare_mdfeed_repo.log
}


create_sw_signing_cert() {
    echo 'Test setup 04: create MD signing certificate'
    /scripts/create_sw_cert.sh unittest
}


create_git_ssh_keys() {
    echo "Test setup 05: create SSH keys for access to $MDFEED_HOST"
    /scripts/gen_sshkey.sh > $LOGDIR/test05.log
    head -4 $LOGDIR/test05.log > $LOGDIR/test05_top4.log
    /tests/assert_nodiff.sh $LOGDIR/test05_top4.log /opt/testdata/results/gen_sshkey/test05_top4.log
}

main "$@"