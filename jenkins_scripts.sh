#!/bin/bash -e
if [[ "$BASH_TRACE" ]]; then
    set -xv
    PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
fi

exec_compose() {
    local cmd=$1
    export COMPOSE_PROJECT_NAME=$project  # option -p not reliable with compose 1.18.0
    echo "docker-compose $compose_f_opt $projopt ${cmd}"
    docker-compose $compose_f_opt $projopt ${cmd}
    local rc=$?
    if ((rc!=0)); then
        echo "docker-compose failed with rc=${rc}"
        return 1
    fi
}


remove_container_if_not_running() {
    local container=$1
    printf 'remove container if not running'
    local status=$(docker container inspect -f '{{.State.Status}}' $container 2>/dev/null || echo '')
    if [[ "$status" ]]; then
        docker container rm -f $container >/dev/null 2>&1 || true # remove any stopped container
    fi
    echo '.'
}


remove_containers() {
    echo 'remove containers'
    for cont in $*; do
        local container_found=$(docker container inspect -f '{{.Name}}' $cont 2>/dev/null || true)
        if [[ "$container_found" ]]; then
            docker container rm -f $container_found -v |  perl -pe 'chomp; print " removed\n"'
        fi
    done
}


remove_volumes() {
    echo 'removing volumes'
    for vol in $*; do
        local volume_found=$(docker volume ls --format '{{.Name}}' --filter name=^$vol$)  # fail job on command error
        if [[ "$volume_found" ]]; then
            docker volume rm $vol |  perl -pe 'chomp; print " removed\n"'
        fi
    done
}


wait_for_container_up() {
    local l_container
    [[ "$1" ]] && l_container=$1 || l_container=$container
    [[ "$2" ]] && wait_max_seconds=$1 || wait_max_seconds=10
    echo "waiting for container status=up"
    local status=''
    until [[ "${status}" == 'running' ]] || (( wait_max_seconds == 0 )); do
        wait_max_seconds=$((wait_max_seconds-=1))
        printf '.'
        sleep 1
        status=$(docker container inspect -f '{{.State.Status}}' $l_container 2>/dev/null || echo '')
    done
    if [[ "${status}" == 'running' ]]; then
        echo "Container $container up"
        return 0
    else
        echo "Container $container not running, status=${status}\n"
        return 1
    fi
}
