pipeline {
    agent any

    stages {
        stage('Pre-Cleanup') {
            steps {
                sh 'docker volume rm 03pyff.etc_pki_sign 03pyff.etc_pyff 03pyff.home_pyff03_ssh 03pyff.var_log 03pyff.var_md_feed 03pyff.var_md_source 2> /dev/null || true'
            }
        }
        stage('Git submodule') {
            steps {
                sh '''
                echo 'Updating submodule'
                git submodule update --init
                cd ./dscripts && git checkout master && git pull && cd ..
                '''
            }
        }
        stage('Build') {
            steps {
                sh '''
                echo 'Building..'
                docker rm --force pyff99 || true
                rm conf.sh 2> /dev/null || true
                ln -s conf.sh.default conf.sh
                ./dscripts/build.sh
                '''
            }
        }
        stage('Test') {
            steps {
                sh '''
                echo 'Testing..'
                ./dscripts/run.sh -I /tests/test_all.sh
                '''
            }
        }
        stage('Post-Cleanup') {
            steps {
                sh 'docker volume rm 99pyff.etc_pki_sign 99pyff.etc_pyff 99pyff.home_pyff99_ssh 99pyff.var_log 99pyff.var_md_feed 99pyff.var_md_source'
            }
        }
    }
}