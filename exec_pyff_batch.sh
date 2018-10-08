#!/usr/bin/env bash

main() {
    get_commandline_opts $@
    get_projdir
    init_sudo
    prepare_command
    exec_commands
}


get_commandline_opts() {
    projdir='.'
    while getopts ":D:ghHn:psS" opt; do
      case $opt in
        D) projdir=$OPTARG;;
        g) git='True';;
        H) htmlout='-H';;
        n) re='^[0-9][0-9]$'
           if ! [[ $OPTARG =~ $re ]] ; then
               echo "error: -n argument ($OPTARG) is not a number in the range frmom 02 .. 99" >&2; exit 1
           fi
           config_nr=$OPTARG;;
        p) print='True';;
        s) split='pyff';;
        S) split='xmlsectool';;
        :) echo "Option -$OPTARG requires an argument"
           exit 1;;
        *) usage; exit 0;;
      esac
    done
    shift $((OPTIND-1))
}


usage() {
    echo "usage: $0 [-h] [-H] [-i] [-s|-S]
       -D  specify docker-compose file directory
       -g  git pull before pyff and push afterwards (use if PYFFOUT has a git repo)
       -h  print this help text
       -H  generate HTML output from metadata
       -n  configuration number ('<NN>' in conf<NN>.sh) (use if there is more than one)
       -p  print docker exec command on stdout
       -s  split and sign md aggregate using pyff for signing
       -S  split and sign md aggregate using xmlsectool for signing"
}


get_projdir() {
    projdir=$(cd $(dirname ${BASH_SOURCE[0]}) && pwd)
}


init_sudo() {
    if (( $(id -u) != 0 )); then
        sudo='sudo -n'
    fi
}


prepare_command() {
    cmd="${sudo} docker-compose -f ${projdir}/dc${config_nr}.yaml exec pyff${config_nr}"
}


exec_commands() {
    set -e
    if [[ $git == 'True' ]]; then
        print_and_exec_command "$cmd /scripts/git_pull.sh"
    fi
    print_and_exec_command "$cmd /scripts/pyff_aggregate.sh $htmlout"
    if [[ "$split" = "pyff" ]]; then
        print_and_exec_command "$cmd /scripts/pyff_mdsplit.sh"
    fi
    if [[ "$split" = "xmlsectool" ]]; then
        print_and_exec_command "$cmd /scripts/pyff_mdsplit_xmlsectool.sh"
    fi
    if [[ $git == 'True' ]]; then
        print_and_exec_command "$cmd /scripts/git_push.sh"
    fi
}


print_and_exec_command() {
    [[ "$print" == "True" ]] && echo $@
    $@

}



main $@
