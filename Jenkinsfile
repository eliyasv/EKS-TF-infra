pipeline {
  agent any   // Run on any available build agent

  environment {
    TF_VERSION = '1.15.0'
    AWS_REGION = 'us-east-1'
    GIT_REPO   = 'https://github.com/eliyasv/EKS-TF-infra.git'
    GIT_BRANCH = 'main'
  }

  // Pipeline parameters: chosen at start of build
  parameters {
    choice(name: 'ENVIRONMENT', choices: ['dev', 'prod'], description: 'Target environment') // Choose which environment to deploy
    choice(name: 'ACTION', choices: ['plan', 'apply', 'destroy'], description: 'Terraform action')  // choose to Plan, apply (deploy), or destroy infrastructure
  }

  // Pipeline runtime options
  options {
    timestamps()      // Prints timestamps in the build log
    disableConcurrentBuilds()  // Only one build runs at once; prevents state file corruption or collisions
  }

  stages {
    stage('Checkout') {
      steps {
        git branch: "${GIT_BRANCH}", url: "${GIT_REPO}"  // Clone code from the repository and branch set by variables above
      }
    }

    stage('Prepare Backend') {
      steps {
        script {
          // Copy backend.tf (with remote state config) for selected environment, replacing any previous backend.tf(implemented this logic as the modules are in structured directories)
          sh "cp environments/${params.ENVIRONMENT}/backend.tf ./backend.tf"
        }
      }
    }

    stage('Terraform Init') {
      steps {
        // Authenticate to AWS using credentials named 'aws-creds'
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
        // Run `terraform fmt` to auto-format the code per best practices (across all subfolders)
        sh 'terraform fmt -recursive'
     }
   }

    stage('Terraform Validate') {
      steps {
        // Check the Terraform configuration syntax and structure for correctness
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
         sh 'terraform validate'
       }
     }
   }



    stage('Terraform Plan Full') {
      when {
        expression { params.ACTION == 'plan' || params.ACTION == 'apply' }
      }
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          // Full plan without targeting (allows Terraform to resolve all dependencies)
          sh "terraform plan -var-file=environments/${params.ENVIRONMENT}/${params.ENVIRONMENT}.tfvars -out=tfplan-${params.ENVIRONMENT}-full"
        }
      }
    }

    stage('Terraform Apply Full') {
      when {
        expression { params.ACTION == 'apply' }
      }
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          // Single comprehensive approval for all infrastructure
          input message: "Approve infrastructure deployment for ${params.ENVIRONMENT}? This will create: IAM roles, VPC, EKS cluster, and node groups.", ok: "Apply All"
          sh "terraform apply -auto-approve tfplan-${params.ENVIRONMENT}-full"
        }
      }
    }

    stage('Terraform Destroy') {
      when {
        // Only run if selected 'destroy'
        expression { params.ACTION == 'destroy' }
      }
      steps {
        withAWS(credentials: 'aws-creds', region: "${AWS_REGION}") {
          // Shows a manual approval prompt before destruction
          input message: "WARNING: This will DESTROY infra in ${params.ENVIRONMENT}. Proceed?", ok: "Destroy"
          // Destroys the infrastructure using environment-specific variables
          sh "terraform destroy -auto-approve -var-file=environments/${params.ENVIRONMENT}/${params.ENVIRONMENT}.tfvars"
        }
      }
    }
  }

  post {
    always {
      // Cleaning up temporary files to prevent cross-environment pollution
      sh 'rm -f backend.tf tfplan-*'
    }
    success {
      echo "✅ Terraform ${params.ACTION} completed for ${params.ENVIRONMENT}."
    }
    failure {
      echo "❌ Terraform ${params.ACTION} failed for ${params.ENVIRONMENT}."
    }
  }
}
