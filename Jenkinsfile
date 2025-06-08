

/////// ******************************* Code for fectching Failed Stage Name ******************************* ///////
import io.jenkins.blueocean.rest.impl.pipeline.PipelineNodeGraphVisitor
import io.jenkins.blueocean.rest.impl.pipeline.FlowNodeWrapper
import org.jenkinsci.plugins.workflow.support.steps.build.RunWrapper
import org.jenkinsci.plugins.workflow.actions.ErrorAction

// Get information about all stages, including the failure cases
// Returns a list of maps: [[id, failedStageName, result, errors]]
@NonCPS
List<Map> getStageResults( RunWrapper build ) {

    // Get all pipeline nodes that represent stages
    def visitor = new PipelineNodeGraphVisitor( build.rawBuild )
    def stages = visitor.pipelineNodes.findAll{ it.type == FlowNodeWrapper.NodeType.STAGE }

    return stages.collect{ stage ->

        // Get all the errors from the stage
        def errorActions = stage.getPipelineActions( ErrorAction )
        def errors = errorActions?.collect{ it.error }.unique()

        return [ 
            id: stage.id, 
            failedStageName: stage.displayName, 
            result: "${stage.status.result}",
            errors: errors
        ]
    }
}

// Get information of all failed stages
@NonCPS
List<Map> getFailedStages( RunWrapper build ) {
    return getStageResults( build ).findAll{ it.result == 'FAILURE' }
}

/////// ******************************* Code for fectching Failed Stage Name ******************************* ///////

pipeline {
  agent any

  environment {
    deploymentName = "devsecops"
    containerName = "devsecops-container"
    serviceName = "devsecops-svc"
    imageName = "akabouri/numeric-app:${GIT_COMMIT}"
    applicationURL="http://devsecops-demopfe.eastus.cloudapp.azure.com"
    applicationURI="/increment/99"
  }

  stages {

    stage('Build Artifact - Maven') {
      steps {
        sh "mvn clean package -DskipTests=true"
        archive 'target/*.jar'
      }
    }


    stage('SonarQube Analysis') {
    steps {
        script {
            def mvn = tool 'Default Maven'
            withCredentials([string(credentialsId: 'sonarqube-token', variable: 'SONAR_TOKEN')]) {
                withSonarQubeEnv('sonarqube') {
                    sh """
                        ${mvn}/bin/mvn clean verify sonar:sonar \
                        -Dsonar.projectKey=numeric-application \
                        -Dsonar.projectName='numeric-application' \
                        -Dsonar.token=${SONAR_TOKEN}
                    """
                }
            }
        }
    }
}

   stage('Vulnerability Scan - dependency-check') {
    steps {   
        sh "mvn dependency-check:check"
        publishHTML([
            allowMissing: false,
            alwaysLinkToLastBuild: true,
            keepAll: true,
            reportDir: 'target',
            reportFiles: 'dependency-check-report.html',
            reportName: 'Dependency Check Report'
        ])
    }
}

      stage('docker scan - trivy'){
        steps{
          sh "bash trivy-docker-image-scan.sh"
          publishHTML([
              allowMissing: false,
              alwaysLinkToLastBuild: true,
              keepAll: true,
              reportDir: '.',
              reportFiles: 'TrivyReport.html',
              reportName: 'Trivy Security Report'
          ])
        }
      }
    

    stage('Docker Build and Push') {
      steps {
        withDockerRegistry([credentialsId: "docker-hub", url: ""]) {
          sh 'printenv'
          sh 'sudo docker build -t akabouri/numeric-app:""$GIT_COMMIT"" .'
          sh 'docker push akabouri/numeric-app:""$GIT_COMMIT""'
        }
      }
    }



    stage('K8S Deployment') {
    steps {
        parallel(
            "Deployment": {
                withKubeConfig([credentialsId: 'kubeconfig']) {
                    script {
                        // Remplacer l'image dans le fichier YAML
                        sh """
                            sed -i "s#replace#${imageName}#g" k8s_deployment_service.yaml
                            
                            # Appliquer le deployment
                            kubectl -n default apply -f k8s_deployment_service.yaml
                            
                            echo "Deployment appliqué avec l'image: ${imageName}"
                        """
                    }
                }
            },
            "Rollout Status": {
                withKubeConfig([credentialsId: 'kubeconfig']) {
                    script {
                        // Attendre avant de vérifier le status
                        sh """
                            echo "Attente de 60 secondes pour le déploiement..."
                            sleep 60
                            
                            # Vérifier le status du rollout
                            if kubectl -n default rollout status deploy ${deploymentName} --timeout=5s | grep -q "successfully rolled out"; then
                                echo "Deployment ${deploymentName} Rollout is Success"
                            else
                                echo "Deployment ${deploymentName} Rollout has Failed"
                                kubectl -n default rollout undo deploy ${deploymentName}
                                exit 1
                            fi
                        """
                    }
                }
            }
        )
    }
}


   stage('OWASP ZAP - DAST') {
      steps {
        withKubeConfig([credentialsId: 'kubeconfig']) {
          sh 'bash zap.sh'
        }
         publishHTML([
            allowMissing: false, 
            alwaysLinkToLastBuild: true, 
            keepAll: true, 
            reportDir: 'owasp-zap-report', 
            reportFiles: 'zap_report.html', 
            reportName: 'OWASP ZAP HTML Report', 
            reportTitles: 'OWASP ZAP HTML Report'
        ])
      }
      
    }

  
  }

  

}