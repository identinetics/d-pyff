#!/usr/bin/env bash

# make ssh-key for github deploy keys and register ssh host alias

main() {
    get_commandline_opts "$@"
    block_root
    test_required_env_vars
    generate_sshkey
    create_MDFEED_HOST_alias
    register_sshkey
}


get_commandline_opts() {
    while getopts ":hdn:" opt; do
      case $opt in
        d) dryrun='True';;
        n) keyname=$OPTARG;;
        :) echo "Option -$OPTARG requires an argument"; exit 1;;
        *) usage; exit 1;;
      esac
    done
}


usage() {
    echo "Generate ssh-keys and test
       usage: $0 [-h] [-n keyname]
       -d  dry run
       -h  print this help text
       -n  suffix for the key file name (used for multiple ssh keys with git)
       "
}


block_root() {
    if (( $(id -u) == 0 )); then
        echo "Do not start as root: ssh keys are required for the regular container user."
    fi
}


test_required_env_vars() {
    [[ -z $MDFEED_HOST ]] && echo "MDFEED_HOST not set" && exit 1
}


generate_sshkey() {
    if [[ ! -e ~/.ssh/id_ed25519 ]] && [[ "$dryrun" != 'True' ]]; then
        ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519_${keyname} -N ''
    fi
}


create_MDFEED_HOST_alias() {
    if [[ ! -z ${keyname+x} ]]; then
        touch ~/.ssh/config
        cat >> ~/.ssh/config << EOT

Host ${keyname}
Hostname $MDFEED_HOST
IdentityFile /home/$(whoami)/.ssh/id_ed25519_${keyname}

EOT
        chmod 600 /home/$(whoami)/.ssh/config
    fi
}


register_sshkey() {
    echo "created new public key - register with $MDFEED_HOST/$repo:"
    if [[ -e ~/.ssh/id_ed25519_${keyname}.pub ]]; then
        cat ~/.ssh/id_ed25519_${keyname}.pub
    fi
}


main "$@"