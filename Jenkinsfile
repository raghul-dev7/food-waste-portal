
pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        timestamps()
        disableConcurrentBuilds()
    }

    parameters {
        booleanParam(
            name: 'FAULTY_RELEASE',
            defaultValue: false,
            description: 'Check only to demonstrate failed deployment and automatic rollback.'
        )
    }

    environment {
        DOCKER_IMAGE = 'raghuldev7/food-waste-portal'
        K8S_DEPLOYMENT = 'food-waste-portal'
        K8S_CONTAINER = 'food-waste-portal'
        K8S_NAMESPACE = 'default'
    }

    stages {

        stage('1. Clone GitHub Repository') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/raghul-dev7/food-waste-portal.git'

                echo 'GitHub repository cloned successfully.'
            }
        }

        stage('2. Parallel Validation') {
            parallel {

                stage('HTML and File Validation') {
                    steps {
                        script {
                            def requiredFiles = [
                                'index.html',
                                'Dockerfile',
                                'Jenkinsfile',
                                'deployment.yaml'
                            ]

                            for (def f : requiredFiles) {
                                if (!fileExists(f)) {
                                    error("Required file is missing: ${f}")
                                }
                            }
                        }

                        echo 'All required project files exist.'
                    }
                }

                stage('Food Portal Content Test') {
                    steps {
                        script {
                            def html = readFile('index.html').toLowerCase()

                            def requiredContent = [
                                'vegetable rice',
                                'bread and buns',
                                'collection deadline',
                                'redistribution'
                            ]

                            for (def item : requiredContent) {
                                if (!html.contains(item)) {
                                    error("Portal content test failed: ${item}")
                                }
                            }
                        }

                        echo 'Food records and portal content verified.'
                    }
                }
            }
        }

        stage('3. Archive Application Files') {
            steps {
                archiveArtifacts(
                    artifacts: 'index.html,Dockerfile,Jenkinsfile,deployment.yaml',
                    fingerprint: true
                )
            }
        }

        stage('4. Build and Push Docker Image') {
            steps {
                script {
                    def imageTag = "build-${env.BUILD_NUMBER}"
                    def faulty = params.FAULTY_RELEASE ? 'true' : 'false'

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub',
                            usernameVariable: 'DOCKER_USER',
                            passwordVariable: 'DOCKER_PASS'
                        )
                    ]) {
                        bat '''
                            @echo off
                            echo Logging in to Docker Hub...
                            echo %DOCKER_PASS% | docker login -u "%DOCKER_USER%" --password-stdin
                            if errorlevel 1 exit /b 1
                        '''

                        bat """
                            docker build --build-arg FAULTY_RELEASE=${faulty} -t ${DOCKER_IMAGE}:${imageTag} .
                            if errorlevel 1 exit /b 1
                            docker push ${DOCKER_IMAGE}:${imageTag}
                            if errorlevel 1 exit /b 1
                        """
                    }

                    echo "Docker image pushed: ${DOCKER_IMAGE}:${imageTag}"
                }
            }
        }

        stage('5. Save Previous Kubernetes Image') {
            steps {
                script {
                    bat """
                        kubectl get deployment ${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE}
                        if errorlevel 1 exit /b 1
                    """

                    env.PREVIOUS_IMAGE = bat(
                        script: """
                            @echo off
                            kubectl get deployment ${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} -o jsonpath="{.spec.template.spec.containers[0].image}"
                        """,
                        returnStdout: true
                    ).trim()

                    if (!env.PREVIOUS_IMAGE) {
                        error('Could not determine the previous Kubernetes image.')
                    }

                    echo "Previous image: ${env.PREVIOUS_IMAGE}"
                }
            }
        }

        stage('6. Deploy to Kubernetes') {
            steps {
                script {
                    def imageTag = "build-${env.BUILD_NUMBER}"

                    bat """
                        kubectl set image deployment/${K8S_DEPLOYMENT} ${K8S_CONTAINER}=${DOCKER_IMAGE}:${imageTag} -n ${K8S_NAMESPACE}
                        if errorlevel 1 exit /b 1
                    """

                    echo "Deploying ${DOCKER_IMAGE}:${imageTag}"
                }
            }
        }

        stage('7. Verify Deployment Health') {
            steps {
                script {
                    int rolloutStatus = bat(
                        script: """
                            @echo off
                            kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=90s
                        """,
                        returnStatus: true
                    )

                    if (rolloutStatus != 0) {
                        echo 'Deployment health check failed. Starting automatic rollback.'

                        bat """
                            kubectl rollout undo deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE}
                            if errorlevel 1 exit /b 1
                            kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=90s
                            if errorlevel 1 exit /b 1
                        """

                        error('New deployment failed. Rollback completed.')
                    }

                    echo 'Kubernetes rollout is healthy.'
                }
            }
        }

        stage('8. Final Verification') {
            steps {
                bat """
                    kubectl get deployments ${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE}
                    kubectl get pods -n ${K8S_NAMESPACE} -o wide
                    kubectl get service food-waste-portal-service -n ${K8S_NAMESPACE}
                """

                echo 'Food Waste Portal deployment verification completed.'
            }
        }
    }

    post {
        success {
            echo 'PIPELINE SUCCESS: Food Waste Portal deployed successfully.'
        }

        failure {
            echo 'PIPELINE FAILED: Check the console output for the failed stage.'
        }

        always {
            echo 'Food Waste Portal CI/CD pipeline finished.'
        }
    }
}
