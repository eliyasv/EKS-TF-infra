pipeline {
  agent any

  environment {
    TF_VERSION = '1.8.5'
    AWS_REGION = 'us-east-1'
    GIT_REPO   = 'https://github.com/eliyasv/EKS-TF-infra.git'
    GIT_BRANCH = 'main'
  }

  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'prod'], description: 'Target environment')
    choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action')
  }

  options {
    timestamps()
    disableConcurrentBuilds()
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: "${GIT_BRANCH}", url: "${GIT_REPO}"
      }
    }

    stage('Terraform Init') {
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          dir("environments/${params.ENVIRONMENT}") {
            sh """
              which terraform 
              terraform --version
              terraform init -reconfigure
            """
          }
        }
      }
    }

    stage('Terraform Format & Validate') {
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          dir("environments/${params.ENVIRONMENT}") {
            sh 'terraform fmt -recursive -check'
            sh 'terraform validate'
          }
        }
      }
    }

    stage('Terraform Plan') {
      when {
        expression { params.ACTION == 'plan' || params.ACTION == 'apply' }
      }
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          dir("environments/${params.ENVIRONMENT}") {
            sh "terraform plan -var-file=${params.ENVIRONMENT}.tfvars -out=tfplan-${params.ENVIRONMENT}"
          }
        }
      }
    }

    stage('Terraform Apply') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          dir("environments/${params.ENVIRONMENT}") {
            input message: "Are you sure you want to APPLY changes to ${params.ENVIRONMENT}?", ok: "Yes, apply"
            sh "terraform apply -auto-approve tfplan-${params.ENVIRONMENT}"
          }
        }
      }
    }

    stage('Terraform Destroy') {
      when {
        expression { params.ACTION == 'destroy' }
      }
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          dir("environments/${params.ENVIRONMENT}") {
            input message: "WARNING: This will DESTROY infra in ${params.ENVIRONMENT}. Proceed?", ok: "Destroy"
            sh "terraform destroy -auto-approve -var-file=${params.ENVIRONMENT}.tfvars"
          }
        }
      }
    }
  }

  post {
    success {
      echo "Terraform ${params.ACTION} completed for ${params.ENVIRONMENT}."
    }
    failure {
      echo "Terraform ${params.ACTION} failed for ${params.ENVIRONMENT}."
    }
  }
}