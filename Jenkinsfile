
pipeline {
    agent any

    parameters {
        booleanParam(
            name: 'FAULTY_RELEASE',
            defaultValue: false,
            description: 'Enable this to test deployment failure and rollback'
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
            }
        }

        stage('2. Validate Application Files') {
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
                }

                bat 'findstr /i /c:"Vegetable Rice" index.html'
                bat 'findstr /i /c:"Bread and Buns" index.html'
                bat 'findstr /i /c:"collection deadline" index.html'
                bat 'findstr /i /c:"redistribution" index.html'
            }
        }

        stage('3. Archive Application Files') {
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
                        credentialsId: 'dockerhub-foodwaste-202',
                        usernameVariable: 'DOCKER_USER',
                        passwordVariable: 'DOCKER_PASS'
                    )
                ]) {
                    script {
                        def faulty = params.FAULTY_RELEASE ? 'true' : 'false'

                        bat '''
                            @echo off
                            echo Logging in to Docker Hub
                            echo %DOCKER_PASS% | docker login -u %DOCKER_USER% --password-stdin
                            if errorlevel 1 exit /b 1
                        '''

                        bat """
                            docker build --build-arg FAULTY_RELEASE=${faulty} -t %DOCKER_IMAGE%:build-%BUILD_NUMBER% .
                            if errorlevel 1 exit /b 1
                            docker push %DOCKER_IMAGE%:build-%BUILD_NUMBER%
                            if errorlevel 1 exit /b 1
                        """
                    }
                }
            }
        }

        stage('5. Save Previous Kubernetes Image') {
            steps {
                script {
                    env.PREVIOUS_IMAGE = bat(
                        script: '''
                            @echo off
                            kubectl get deployment %K8S_DEPLOYMENT% -n %K8S_NAMESPACE% -o jsonpath="{.spec.template.spec.containers[?(@.name==\\"%K8S_CONTAINER%\\")].image}"
                        ''',
                        returnStdout: true
                    ).trim()

                    if (!env.PREVIOUS_IMAGE) {
                        error('Could not read the current Kubernetes image. Check the deployment and container names.')
                    }

                    echo "Previous image: ${env.PREVIOUS_IMAGE}"
                }
            }
        }

        stage('6. Deploy to Kubernetes') {
            steps {
                bat '''
                    kubectl set image deployment/%K8S_DEPLOYMENT% %K8S_CONTAINER%=%DOCKER_IMAGE%:build-%BUILD_NUMBER% -n %K8S_NAMESPACE%
                    if errorlevel 1 exit /b 1
                '''
            }
        }

        stage('7. Verify and Roll Back if Needed') {
            steps {
                script {
                    def rolloutStatus = bat(
                        script: '''
                            @echo off
                            kubectl rollout status deployment/%K8S_DEPLOYMENT% -n %K8S_NAMESPACE% --timeout=120s
                        ''',
                        returnStatus: true
                    )

                    if (rolloutStatus != 0) {
                        echo 'Deployment failed. Rolling back to the previous image.'

                        bat """
                            kubectl set image deployment/%K8S_DEPLOYMENT% %K8S_CONTAINER%=${env.PREVIOUS_IMAGE} -n %K8S_NAMESPACE%
                            kubectl rollout status deployment/%K8S_DEPLOYMENT% -n %K8S_NAMESPACE% --timeout=120s
                        """

                        error('Deployment failed. Rollback attempted; pipeline marked as FAILURE.')
                    }

                    echo 'Deployment rollout succeeded.'
                }
            }
        }

        stage('8. Final Verification') {
            steps {
                bat 'kubectl get deployment %K8S_DEPLOYMENT% -n %K8S_NAMESPACE%'
                bat 'kubectl get pods -n %K8S_NAMESPACE% -o wide'
                bat 'kubectl get service food-waste-portal-service -n %K8S_NAMESPACE%'
            }
        }
    }

    post {
        success {
            echo 'Food Waste Portal deployed successfully.'
        }
        failure {
            echo 'Pipeline failed. Check Console Output and rollback logs.'
        }
        always {
            echo 'Food Waste Portal pipeline finished.'
        }
    }
}
