#!/usr/bin/env bash

main() {
    get_commandline_opts $@
    start_sshd
}


get_commandline_opts() {
    daemonmode='-D'
    while getopts ":dh" opt; do
      case $opt in
        d) daemonmode='';;
        *) usage; exit 0;;
      esac
    done
}


usage() {
    echo "usage: $0 [-d] [-h]
       -d  start in background (default: foreground)
       -h  print this help text
       "
}


start_sshd() {
    echo 'starting sshd'
    /usr/sbin/sshd ${daemonmode} -f /opt/etc/ssh/sshd_config
    # login like 'ssh -o "StrictHostKeyChecking no" -i ~/.ssh/id_ed25519_loopback -p 2022 <someuser>@thishost'
}


main "$@"
