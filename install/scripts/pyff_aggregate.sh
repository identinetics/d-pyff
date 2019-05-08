#!/bin/sh

main() {
    #block_root
    aggregate_metadata
}


block_root() {
    if (( $(id -u) == 0 )); then
        echo "Do not start as root."
        exit 1
    fi
}


aggregate_metadata() {
    if [[ -f "$PIPELINEBATCH" ]]; then
        LC_ALL=en_US.UTF-8 \
        /usr/bin/pyff --loglevel=$LOGLEVEL --logfile=$LOGDIR/pyff.lastlog $PIPELINEBATCH
    else
        echo "PIPELINEBATCH missing"
        exit 3
    fi
    rc=$?
    if (( rc > 0 )); then
        echo "/usr/bin/pyff failed with rc=${rc}"
        exit $rc
    fi
    touch $LOGDIR/pyff.log
    cat $LOGDIR/pyff.lastlog >> $LOGDIR/pyff.log
    chmod 644 /var/md_feed/*.xml 2> /dev/null
}


main "$@"
