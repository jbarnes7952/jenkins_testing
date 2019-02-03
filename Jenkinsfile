pipeline {
	agent { docker { image 'packer_build_env'  }  }
	environment {
		AWS_ACCESS_KEY_ID     = credentials('AWS_ACCESS_KEY_ID')
		AWS_SECRET_ACCESS_KEY = credentials('AWS_SECRET_ACCESS_KEY')
	}
	stages {
		stage('build') {
			steps {
				sh 'packer build packer.json'
			}

		}
		stage('plan') {
			steps {
				sh 'terraform init'
				sh 'terraform plan'
			}

		}
		stage('apply') {
			steps {
				sh 'terraform apply -auto-approve'
			}

		}

	}

}
