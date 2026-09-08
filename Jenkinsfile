pipeline {
    agent any
    parameters {
        booleanParam(name: 'SKIP_TESTS', defaultValue: false, description: 'Skip the Run Frontend Tests stage')
    }
    environment {
        registry = "837577998611.dkr.ecr.us-west-2.amazonaws.com/kpi"
        clustername = "eks-sbs-dev"
        region = "us-west-2"
        ns = "sbsdev"
        ecrauth = "aws ecr get-login-password --region us-west-2 | docker login --username AWS --password-stdin 837577998611.dkr.ecr.us-west-2.amazonaws.com"

        SLACK_CHANNEL = "#jenkins" // Centralized Slack notification channel
        SERVICE_NAME = "Form Designer"
       }
	   
    stages {
        stage('Checkout') {
            steps {
                // Notify Build Start
                slackSend(
                    channel: env.SLACK_CHANNEL,
                    message: "${env.SERVICE_NAME} deploy for branch ${env.release_branch} - STARTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})"
                )
                cleanWs()
                checkout scmGit(branches: [[name: '*/$release_branch']], extensions: [], userRemoteConfigs: [[credentialsId: 'jenkins-github-token-as-password', url: 'https://github.com/OpenClinica/kpi.git']])
            }
        }
        
        stage('Run Frontend Tests') {
            when {
                expression { ["build", "build & deploy"].contains(env.ENV) && !params.SKIP_TESTS }
            }
            agent {
                docker {
                    image 'node:20.18.1-bookworm'
                    args '--user root:root --shm-size=2g'
                    reuseNode true
                }
            }
            environment {
                HUSKY = '0'
                DEBIAN_FRONTEND = 'noninteractive'
            }
            steps {
                // OC fork: authenticate the private @openclinica/logic-builder clone.
                // The credential is a Username-with-password (username + GitHub token),
                // so bind it with usernamePassword — a string() binding fails with
                // "is of type 'Username with password' where StringCredentials was
                // expected". usernameVariable is a required parameter of the binding;
                // GH_USER is intentionally unused (masked, stage-scoped) — the URL uses
                // the fixed x-access-token username so an empty/misconfigured stored
                // username can't break auth (GitHub ignores the username for PATs).
                // Single-quoted sh body -> ${GH_TOKEN} expands in the shell from the
                // masked credential env var, never in Groovy (so it isn't logged).
                withCredentials([usernamePassword(credentialsId: 'jenkins-github-token-as-password', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
                    sh '''
                        set -e
                        apt-get update -qq
                        apt-get install -y --no-install-recommends python3 git
                        ln -sf /usr/bin/python3 /usr/bin/python
                        rm -rf /var/lib/apt/lists/*
                        # Scope the token to a throwaway gitconfig (never the persistent
                        # ~/.gitconfig, which can linger with reuseNode). GIT_CONFIG_GLOBAL
                        # points git — and the git children npm spawns — at it; the trap
                        # wipes it on exit, success or failure.
                        export GIT_CONFIG_GLOBAL="$(mktemp)"
                        trap 'rm -f "$GIT_CONFIG_GLOBAL"' EXIT
                        git config --global url."https://x-access-token:${GH_TOKEN}@github.com/".insteadOf "ssh://git@github.com/"
                        npm ci --legacy-peer-deps --cache /tmp/.npm-cache
                        npm run test:unit
                    '''
                }
            }
        }

        stage('Fetch ECR Credentials') {
            steps {
                script {
                    sh "${ecrauth}"
                    sh "df -h"
                }
            }
        }
        stage('Configure EKS Cluster') {
            steps {
                sh '/usr/local/bin/eksctl version'
                sh '/usr/local/bin/eksctl utils write-kubeconfig --cluster=${clustername} --region=${region}'
                sh "ssh -J root@sbs-dev-jump -D 1094 -f root@eks-maintenance-dev -N"
            }
        }
        stage ("Build and Push Image to ECR") {
            steps {
              script {
                if ( env.ENV == "build" || env.ENV == "build & deploy") {
                    sh """
                        # Unset DOCKER_HOST to ensure commands target the local Docker daemon by default
                        unset DOCKER_HOST
                        if docker buildx inspect arm64builder > /dev/null 2>&1; then
                            docker buildx rm arm64builder
                        fi
                        docker buildx create --name arm64builder --node arm64 --platform linux/aarch64
                        docker buildx inspect --bootstrap --builder arm64builder
                       """
                    // OC fork: pass the GitHub token to BuildKit as a secret so the
                    // Dockerfile's npm-install stage can clone the private
                    // @openclinica/logic-builder (id must match the Dockerfile's
                    // `--mount=type=secret,id=gh_token`). The credential is a
                    // Username-with-password, so bind with usernamePassword and feed
                    // only the password component (the token) to BuildKit; `env=GH_TOKEN`
                    // reads the masked env var, so it never appears in the log.
                    // usernameVariable is required by the binding — GH_USER is unused
                    // here (the Dockerfile authenticates as x-access-token).
                    withCredentials([usernamePassword(credentialsId: 'jenkins-github-token-as-password', usernameVariable: 'GH_USER', passwordVariable: 'GH_TOKEN')]) {
                        sh "docker buildx build --builder arm64builder --platform linux/aarch64 --secret id=gh_token,env=GH_TOKEN -t ${registry}:${tag_version} --push ."
                    }
                  }
                else {
                    sh "echo 'Skipping this step'" 
                }    
             }
           }
        }       
        stage ("Sanitize Workspace") {
            steps {
                cleanWs()
            }

        }
        stage ('Helm checkout') {
            steps {
                script {
                if ( env.ENV == "build & deploy" || env.ENV == "deploy" )
                {
                checkout scmGit(branches: [[name: '*/main']], extensions: [], userRemoteConfigs: [[credentialsId: 'jenkins-github-token-as-password', url: 'https://github.com/OpenClinica/container-ops.git']])
                }
                 else {
                sh "echo 'Skipping this step'" 
                }        
              }
            }
           }         
        stage('Deploy Helm Chart') {
            steps {
               script {
                if ( env.ENV == "build & deploy" || env.ENV == "deploy" )
                {
                sh "https_proxy=socks5://127.0.0.1:1094 /usr/local/bin/helm upgrade formdesigner --install apps/kobo_kpi --values apps/kobo_kpi/values-dev.yaml --namespace ${ns} --set kpi.image.repository=${registry} --set kpi.image.tag=${tag_version}"
                }
                else {
                sh "echo 'Skipping this step'" 
                }        
             }
          }
      }
   }

    post {
        success {
            // Notify Success with custom message
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: 'good',
                message:  "${env.SERVICE_NAME} deploy for branch ${env.release_branch} - SUCCESS: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})\nSuccessfully deployed to EKS"
            )
        }
        aborted {
            // Notify Aborted
            slackSend(
                channel: env.SLACK_CHANNEL,
                color: 'warning',
                message: "${env.SERVICE_NAME} deploy for branch ${env.release_branch} - ABORTED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})"
            )
        }
        failure {
            script {
                // Notify First Failure Only
                def previousBuild = currentBuild.previousBuild
                if (previousBuild == null || previousBuild.result != 'FAILURE') {
                    slackSend(
                        channel: env.SLACK_CHANNEL,
                        color: 'danger',
                        message: "${env.SERVICE_NAME} deploy for branch ${env.release_branch} - FAILED: Job '${env.JOB_NAME} [${env.BUILD_NUMBER}]' (${env.BUILD_URL})"
                    )
                }
            }
        }
    }
}
