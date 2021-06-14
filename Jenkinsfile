pipeline {
    agent any
    stages {
        stage('first'){
            steps{
                git 'https://github.com/geek-kb/DevopsStuff.git'
            }
        }
        stage('something'){
            steps{
                sh 'echo hi'
            }
        }
        stage('this will trigger the job'){
            steps{
                sh 'echo trigger'
            }
        }
    }
}
