pipeline {
    agent any

    options {
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        string(
            name: 'EC2_HOST',
            defaultValue: '',
            description: 'Public IP address of the EC2 instance'
        )
    }

    environment {
        IMAGE_REPOSITORY = 'mufarin/devops-environment-validator'
    }

    stages {
        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Prepare Workspace') {
            steps {
                script {
                    env.LOCAL_UID = sh(
                        script: 'id -u',
                        returnStdout: true
                    ).trim()

                    env.LOCAL_GID = sh(
                        script: 'id -g',
                        returnStdout: true
                    ).trim()
                }

                sh 'mkdir -p generated'
            }
        }

        stage('Build Validator Image') {
            steps {
                sh 'docker compose build'
            }
        }

        stage('Validate Configuration') {
            steps {
                sh 'docker compose run --rm validator'
            }
        }

        stage('Validate Terraform') {
            steps {
                sh 'terraform -chdir=terraform init -backend=false -input=false'
                sh 'terraform -chdir=terraform fmt -check'
                sh 'terraform -chdir=terraform validate'
            }
        }

        stage('Configure Server with Ansible') {
            steps {
                script {
                    if (!params.EC2_HOST?.trim()) {
                        error('EC2_HOST parameter is required')
                    }
                }

                withCredentials([
                    sshUserPrivateKey(
                        credentialsId: 'aws-ssh-key',
                        keyFileVariable: 'SSH_KEY_FILE',
                        usernameVariable: 'SSH_USER'
                    )
                ]) {
                    script {
                        writeFile(
                            file: 'ansible/inventory.yml',
                            text: """all:
  children:
    aws:
      hosts:
        ec2:
          ansible_host: ${params.EC2_HOST}
          ansible_user: ${env.SSH_USER}
          ansible_ssh_private_key_file: ${env.SSH_KEY_FILE}
          ansible_python_interpreter: /usr/bin/python3
"""
                        )
                    }

                    sh '''
                        ANSIBLE_HOST_KEY_CHECKING=False \
                        ansible-playbook \
                        -i ansible/inventory.yml \
                        ansible/playbook.yml
                    '''
                }
            }
        }

        stage('Publish Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub-credentials',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_TOKEN'
                    )
                ]) {
                    sh '''
                        echo "$DOCKER_TOKEN" |
                        docker login \
                        --username "$DOCKER_USER" \
                        --password-stdin

                        docker push "$IMAGE_REPOSITORY:latest"

                        docker tag \
                        "$IMAGE_REPOSITORY:latest" \
                        "$IMAGE_REPOSITORY:$BUILD_NUMBER"

                        docker push "$IMAGE_REPOSITORY:$BUILD_NUMBER"
                    '''
                }
            }
        }
    }

    post {
        success {
            echo 'Environment Builder pipeline completed successfully.'
        }

        failure {
            echo 'Environment Builder pipeline failed. Check the failed stage.'
        }

        always {
            sh 'docker logout || true'
        }
    }
}


//   Fluxul este : GitHub > build validator -> validare config > verificare Terraform >
//  instalare si verificare prin Ansible > publicare imagine pe Docker Hub
