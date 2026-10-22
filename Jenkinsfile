
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
            description: 'Check to demonstrate a faulty release and automatic rollback.'
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
                                    error("Required file missing: ${f}")
                                }
                            }
                        }

                        echo 'All required files exist.'
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
                                    error("Content test failed: ${item}")
                                }
                            }
                        }

                        echo 'Food portal content verified.'
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

                echo 'Application files archived.'
            }
        }

        stage('4. Build and Push Docker Image') {
            steps {
                script {
                    def imageTag = "build-${env.BUILD_NUMBER}"
                    def faulty = params.FAULTY_RELEASE ? 'true' : 'false'

                    withCredentials([
                        usernamePassword(
                            credentialsId: 'dockerhub-foodwaste-2026',
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

                    env.NEW_IMAGE = "${DOCKER_IMAGE}:${imageTag}"

                    echo "Docker image pushed: ${env.NEW_IMAGE}"
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
                        error('Could not find the previous Kubernetes image.')
                    }

                    echo "Previous image: ${env.PREVIOUS_IMAGE}"
                }
            }
        }

        stage('6. Deploy to Kubernetes') {
            steps {
                bat """
                    kubectl set image deployment/${K8S_DEPLOYMENT} ${K8S_CONTAINER}=${env.NEW_IMAGE} -n ${K8S_NAMESPACE}
                    if errorlevel 1 exit /b 1
                """

                echo 'New image submitted to Kubernetes.'
            }
        }

        stage('7. Verify Deployment and Roll Back if Needed') {
            steps {
                script {
                    int status = bat(
                        script: """
                            @echo off
                            kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=90s
                        """,
                        returnStatus: true
                    )

                    if (status != 0) {
                        echo 'Deployment failed. Restoring previous image.'

                        bat """
                            kubectl set image deployment/${K8S_DEPLOYMENT} ${K8S_CONTAINER}=${env.PREVIOUS_IMAGE} -n ${K8S_NAMESPACE}
                            if errorlevel 1 exit /b 1

                            kubectl rollout status deployment/${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE} --timeout=90s
                            if errorlevel 1 exit /b 1
                        """

                        error('Faulty deployment detected. Previous image restored.')
                    }

                    echo 'Deployment rollout succeeded.'
                }
            }
        }

        stage('8. Final Verification') {
            steps {
                bat """
                    kubectl get deployment ${K8S_DEPLOYMENT} -n ${K8S_NAMESPACE}
                    kubectl get pods -n ${K8S_NAMESPACE}
                    kubectl get service food-waste-portal-service -n ${K8S_NAMESPACE}
                """

                echo 'Final Kubernetes verification completed.'
            }
        }
    }

    post {
        success {
            echo 'SUCCESS: Food Waste Portal deployed successfully.'
        }

        failure {
            echo 'FAILURE: Check Console Output for the failed stage.'
        }

        always {
            echo 'Food Waste Portal CI/CD pipeline finished.'
        }
    }
}
