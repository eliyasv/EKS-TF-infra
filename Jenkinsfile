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

    stage('Prepare Backend') {
      steps {
        script {
          // Copy the per-env backend.tf to root
          sh "cp environments/${params.ENVIRONMENT}/backend.tf ./backend.tf"
        }
      }
    }

    stage('Terraform Init') {
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          sh """
            which terraform
            terraform --version
            terraform init -reconfigure
          """
        }
      }
    }

    stage('Terraform Format') {
      steps {
        sh 'terraform fmt -recursive'
     }
   }

    stage('Terraform Validate') {
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
         sh 'terraform validate'
       }
     }
   }


    stage('Terraform Plan') {
      when {
        expression { params.ACTION == 'plan' || params.ACTION == 'apply' }
      }
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          sh "terraform plan -var-file=environments/${params.ENVIRONMENT}/${params.ENVIRONMENT}.tfvars -out=tfplan-${params.ENVIRONMENT}"
        }
      }
    }

    stage('Terraform Apply') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          input message: "Are you sure you want to APPLY changes to ${params.ENVIRONMENT}?", ok: "Yes, apply"
          sh "terraform apply -auto-approve tfplan-${params.ENVIRONMENT}"
        }
      }
    }

    stage('Terraform Destroy') {
      when {
        expression { params.ACTION == 'destroy' }
      }
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          input message: "WARNING: This will DESTROY infra in ${params.ENVIRONMENT}. Proceed?", ok: "Destroy"
          sh "terraform destroy -auto-approve -var-file=environments/${params.ENVIRONMENT}/${params.ENVIRONMENT}.tfvars"
        }
      }
    }
  }

  post {
    success {
      echo "✅ Terraform ${params.ACTION} completed for ${params.ENVIRONMENT}."
    }
    failure {
      echo "❌ Terraform ${params.ACTION} failed for ${params.ENVIRONMENT}."
    }
  }
}
