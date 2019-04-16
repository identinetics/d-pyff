pipeline {
    agent any
    options { disableConcurrentBuilds() }
    environment {
        compose_cfg='dc.yaml'
        compose_f_opt='-f dc.yaml'
        container='pyff'
        d_app_volumes='03pyff.etc_pki_sign 03pyff.etc_pyff 03pyff.home_pyff_ssh 03pyff.var_log 03pyff.var_md_feed 03pyff.var_md_source'
        project='j_pyff'
        projopt="-p $project"
        //BASH_TRACE=1
    }
    parameters {
        string(defaultValue: 'True', description: '"True": initial cleanup: remove container and volumes; otherwise leave empty', name: 'start_clean')
        string(description: '"True": "Set --nocache for docker build; otherwise leave empty', name: 'nocache')
        string(description: '"True": push docker image after build; otherwise leave empty', name: 'pushimage')
        string(description: '"True": keep running after test; otherwise leave empty to delete container and volumes', name: 'keep_running')
    }

    stages {
        stage('Config ') {
            steps {
                sh '''
                   if [[ "$DOCKER_REGISTRY_USER" ]]; then
                        echo "  Docker registry user: $DOCKER_REGISTRY_USER"
                        ./dcshell/update_config.sh "${compose_cfg}.default" $compose_cfg
                    else
                        cp "${compose_cfg}.default" $compose_cfg
                    fi
                    cp env.default env
                    grep ' image:' $compose_cfg || echo "missing key 'service.image' in ${compose_cfg}"
                    grep ' container_name:' $compose_cfg || echo "missing key 'service.container_name' in ${compose_cfg}"
                '''
            }
        }
        stage('Cleanup ') {
            when {
                expression { params.$start_clean?.trim() != '' }
            }
            steps {
                sh '''
                    source ./jenkins_scripts.sh
                    remove_containers pyff && echo '.'
                    remove_volumes $d_app_volumes && echo '.'
                '''
            }
        }
        stage('Build') {
            steps {
                sh '''#!/bin/bash
                    source ./jenkins_scripts.sh
                    remove_container_if_not_running pyff # $container
                    if [[ "$nocache" ]]; then
                         nocacheopt='-c'
                         echo 'build with option nocache'
                    fi
                    export MANIFEST_SCOPE='local'
                    export PROJ_HOME='.'
                    PS4='+(${BASH_SOURCE}:${LINENO}): ${FUNCNAME[0]:+${FUNCNAME[0]}(): }'
                    eval ./dcshell/build -f $compose_cfg $nocacheopt || \
                        (rc=$?; echo "build failed with rc rc?"; exit $rc)
                '''
            }
        }
        stage('Test SoftHSM') {
            steps {
                sh '''
                    source ./jenkins_scripts.sh
                    echo 'Testing..'
                    export MDFEED_HOST='localhost'  #  for ssh-config only, no test yet
                    # softhsm must run as root (to access private key for user osm)
                    exec_compose "-f dc_override_softhsm.yaml run --rm  -u 0 --name ${container} pyff /tests/test_all.sh"
                '''
            }
        }
        stage('Test eToken HSM') {
            when {
                // set SKIPHSM in Jenkins Env Injector plugin for nodes that do not have an HSM installed
                expression { SKIPHSM != '' }
            }
            steps {
                sh '''
                    [[ "$SKIPHSM" ]] && exit 0
                    source ./jenkins_scripts.sh
                    echo 'Testing..'
                    export MDFEED_HOST='localhost'  #  for ssh-config only, no test yet
                    exec_compose "-f dc_override_etoken.yaml run --rm --name ${container} pyff /tests/test_all.sh"
                '''
            }
        }
        stage('Push ') {
            when {
                expression { params.pushimage?.trim() != '' }
            }
            steps {
                sh '''
                    default_registry=$(docker info 2> /dev/null |egrep '^Registry' | awk '{print $2}')
                    echo "  Docker default registry: ${default_registry}"
                    export MANIFEST_SCOPE='local'
                    export PROJ_HOME='.'
                    ./dcshell/build -f $compose_cfg -P
                '''
            }
        }
    }
    post {
        always {
            sh '''
                if [[ "$keep_running" ]]; then
                    echo "Keep container running"
                else
                    echo 'Cleanup: container, volumes'
                    source ./jenkins_scripts.sh
                    exec_compose "rm --force -v" 2>/dev/null || true
                fi
            '''
        }
    }
}