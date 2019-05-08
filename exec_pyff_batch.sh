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
    while getopts ":c:C:D:ghHpsS" opt; do
      case $opt in
        c) composecfg=$OPTARG;;
        C) servicename=$OPTARG;;
        D) projdir=$OPTARG;;
        g) git='True';;
        p) print='True';;
        S) split='xmlsectool';;
        :) echo "Option -$OPTARG requires an argument"
           exit 1;;
        *) usage; exit 0;;
      esac
    done
    shift $((OPTIND-1))
    [[ "$composecfg" && "$servicename" ]] && (echo "-c and -C are mutually exclusive"; exit 1)
    [[ "$composecfg" || "$servicename" ]] || (echo "either -c or -C must be specified"; exit 1)
}


usage() {
    echo "usage: $0 [-c compose-config | -C servicename] [-D] [-g] [-h] [-p] [-S]
       -c  docker compose config file
       -C  Docker service name
       -D  specify docker-compose file directory
       -g  git pull before pyff and push afterwards (use if the publish dir of pyff has a git repo)
       -h  print this help text
       -p  print docker exec command on stdout
       -S  split and sign md aggregate using xmlsectool for signing

       run pyff with docker compose, or exec it in existing service"
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
    if [[ "$composecfg" ]]; then
        cmd="${sudo} docker-compose -f ${projdir}/${composecfg} run pyff"
    else  # get container by servicename (-> `docker service ls`)
        taskid=$(docker service ps -q ${servicename} |head -1)
        containerid=$(docker inspect -f '{{.Status.ContainerStatus.ContainerID}}' ${taskid})
        cmd="docker exec -it ${containerid}"
    fi
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
