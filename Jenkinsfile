
pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'FAULTY_RELEASE',
            defaultValue: false,
            description: 'Build a faulty image to demonstrate automatic rollback'
        )
    }

    environment {
        DOCKER_IMAGE = 'raghuldev7/food-waste-portal'
        K8S_DEPLOYMENT = 'food-waste-portal'
        K8S_CONTAINER = 'food-waste-portal'
    }

    stages {
        stage('1. Clone GitHub Repository') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/raghul-dev7/food-waste-portal.git'
            }
        }

        stage('2. Parallel Validation') {
            parallel {
                stage('HTML Validation') {
                    steps {
                        script {
                            if (!fileExists('index.html')) {
                                error('index.html is missing')
                            }
                            if (!fileExists('Dockerfile')) {
                                error('Dockerfile is missing')
                            }
                            if (!fileExists('deployment.yaml')) {
                                error('deployment.yaml is missing')
                            }
                            if (!fileExists('Jenkinsfile')) {
                                error('Jenkinsfile is missing')
                            }
                        }
                        echo 'All required application files exist'
                    }
                }

                stage('Content Test') {
                    steps {
                        script {
                            def html = readFile('index.html')
                            if (!html.contains('Vegetable Rice') ||
                                !html.contains('Bread and Buns') ||
                                !html.contains('Collection deadline') ||
                                !html.contains('Redistribution')) {
                                error('Food portal content test failed')
                            }
                        }
                        echo 'Sample food records and portal content verified'
                    }
                }
            }
        }

        stage('3. Archive Build Artifacts') {
            steps {
                archiveArtifacts artifacts:
                    'index.html,Dockerfile,Jenkinsfile,deployment.yaml',
                    fingerprint: true
            }
        }

        stage('4. Build and Push Docker Image') {
            steps {
                withCredentials([
                    usernamePassword(
                        credentialsId: 'dockerhub',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    script {
                        def tag = "build-${env.BUILD_NUMBER}"
                        def faulty = params.FAULTY_RELEASE ? 'true' : 'false'

                        bat """
                            docker login -u "%DOCKER_USER%" -p "%DOCKER_PASS%"
                            docker build --build-arg FAULTY_RELEASE=${faulty} -t ${DOCKER_IMAGE}:${tag} .
                            docker push ${DOCKER_IMAGE}:${tag}
                        """

                        env.IMAGE_TAG = tag
                    }
                }
            }
        }

        stage('5. Deploy to Kubernetes') {
            steps {
                script {
                    int rolloutStatus = 0

                    withCredentials([
                        file(
                            credentialsId: 'kuberconfig',
                            variable: 'KUBECONFIG'
                        )
                    ]) {
                        bat """
                            kubectl apply -f deployment.yaml
                            kubectl set image deployment/${K8S_DEPLOYMENT} ${K8S_CONTAINER}=${DOCKER_IMAGE}:${env.IMAGE_TAG}
                        """

                        rolloutStatus = bat(
                            returnStatus: true,
                            script: """
                                kubectl rollout status deployment/${K8S_DEPLOYMENT} --timeout=90s
                            """
                        )

                        if (rolloutStatus != 0) {
                            echo 'ROLLOUT FAILED. Rolling back to previous stable release.'

                            bat """
                                kubectl rollout undo deployment/${K8S_DEPLOYMENT}
                                kubectl rollout status deployment/${K8S_DEPLOYMENT} --timeout=90s
                            """

                            error('New rollout failed; previous stable release restored.')
                        }

                        echo 'Deployment completed successfully.'
                    }
                }
            }
        }

        stage('6. Verify Application') {
            when {
                expression { !params.FAULTY_RELEASE }
            }
            steps {
                withCredentials([
                    file(
                        credentialsId: 'kuberconfig',
                        variable: 'KUBECONFIG'
                    )
                ]) {
                    bat """
                        kubectl get deployments
                        kubectl get pods -l app=food-waste-portal
                        kubectl get service food-waste-portal-service
                    """
                }
            }
        }
    }

    post {
        always {
            echo 'Food Waste Portal pipeline execution finished.'
        }
    }
}

