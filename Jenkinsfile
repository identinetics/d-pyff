// Build-Setup-Test (no prior cleanup; leave container running after test)

pipeline {
    agent any
    options { disableConcurrentBuilds() }
    parameters {
        string(defaultValue: 'True', description: '"True": initial cleanup: remove container and volumes; otherwise leave empty', name: 'start_clean')
        string(description: '"True": "Set --nocache for docker build; otherwise leave empty', name: 'nocache')
        string(description: '"True": push docker image after build; otherwise leave empty', name: 'pushimage')
        string(description: '"True": keep running after test; otherwise leave empty to delete container and volumes', name: 'keep_running')
    }

    stages {
        stage('Job Env') {
            steps {
                sh '''
                    set +x
                    echo "Initial cleanup=start_clean"
                    echo "Build with option nocache=$nocache"
                    echo "Push  image=$pushimage"
                    if [[ "$pushimage" ]]; then
                        default_registry=$(docker info 2> /dev/null |egrep '^Registry' | awk '{print $2}')
                        echo "  Docker default registry: $default_registry"
                    fi
                    echo "Keep running after test=$keep_running"
                '''
            }
        }
        stage('Cleanup ') {
            when {
                expression { params.$start_clean?.trim() != '' }
            }
            steps {
                sh '''
                    #docker-compose -f dc.yaml down -v 2>/dev/null | true
                    docker-compose -f dc.yaml down -v | true
                '''
            }
        }
        stage('Build') {
            steps {
                sh '''
                    [[ "$nocache" ]] && nocacheopt='-c'
                    export MANIFEST_SCOPE='local'
                    ./dcshell/build -f dc.yaml $nocacheopt
                    echo "=== build completed with rc $?"
                '''
            }
        }
        stage('Test ') {
            steps {
                sh '''
                    echo 'Testing..'
                    export REPO_HOST='localhost'  #  for ssh-config only, no test yet
                    docker-compose -f dc.yaml run --rm pyff /tests/test_all.sh
                '''
            }
        }
        stage('Push ') {
            when {
                expression { params.pushimage?.trim() != '' }
            }
            steps {
                sh '''
                    export MANIFEST_SCOPE='local'
                    export PROJ_HOME='.'
                    ./dcshell/build -f dc.yaml -P
                '''
            }
        }
    }
    post {
        always {
            sh '''
                if [[ ! "$keep_running" ]]; then
                    echo 'removing docker volumes and container'
                    docker-compose -f dc.yaml down -v
                fi
            '''
        }
    }

}
