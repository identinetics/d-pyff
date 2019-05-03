#!/bin/sh

main() {
    get_commandline_opts "$@"
    #block_root
    aggregate_metadata
    generate_html
}


get_commandline_opts() {
    while getopts ":hH" opt; do
      case $opt in
        H) htmlout='True';;
        *) usage; exit 1;;
      esac
    done
    shift $((OPTIND-1))
}


usage() {
    echo "usage: $0 [-h] [-H]
       run metadata aggregator
       -h  print this help text
       -H  generate html output from metadata
       "
}


block_root() {
    if (( $(id -u) == 0 )); then
        echo "Do not start as root."
        exit 1
    fi
}


aggregate_metadata() {
    /usr/bin/pyff --loglevel=$LOGLEVEL --logfile=$LOGDIR/pyff.lastlog $PIPELINEBATCH
    rc=$?
    if (( rc > 0 )); then
        echo "/usr/bin/pyff failed with rc=${rc}"
        exit $rc
    fi
    touch $LOGDIR/pyff.log
    cat $LOGDIR/pyff.lastlog >> $LOGDIR/pyff.log
    chmod 644 /var/md_feed/*.xml 2> /dev/null
}


generate_html() {
    if [[ "$htmlout" == 'True' ]]; then
        cd /var/md_feed
        xsltproc -o idp.html /etc/pyff/xslt/idp.xsl metadata.xml
        xsltproc -o sp.html /etc/pyff/xslt/sp.xsl metadata.xml
    fi
}


main "$@"
