## GOAL 2: Deploying to AKS
<br/>

#### 1. Fork this repository
This will allow you to set secret and run your own workflows. Click [here](https://github.com/melzayet/azure-cn-depicted/fork) to fork.

#### 2. Review/Tweak Kubernetes manifest
Navigate to folder "02.DeployAKS", and check the file "AKS/app-manifest.yaml". This defines the deployment, service and ingress for our demo kubernetes app.
Review the manifest and feel free to change any configuration if needed.

#### 3. Review GitHub workflows
Workflows under ".github/workflows" help automate the deployment of infrastructure and apps:

- Deploy AKS infrastructure: aks-cluster-deploy.yml
- Setup AKS cluster: aks-cluster-setup.yml
- Deploy AKS app: aks-app-deploy.yml
- Setup Container Apps infrastructure: aca-infra-deploy.yml
- Deploy Container Apps application: aca-app-deploy.yml

Review this workflow: "aks-app-deploy.yml"

#### 4. Setup deployment and app identity
If you followed "Goal 1" steps this deployment identity was created, and it was given AKS cluster admin role. If not, please assign this RBAC role now.

The app identity was also created. Yet you need to give it now a federated credential as follows:

        //get aks OIDC issuer URL
        az aks show --resource-group <aks-resource-group> --name <aks-cluster-name> --query "oidcIssuerProfile.issuerUrl" -otsv
        
        SERVICE_ACCOUNT_ISSUER=<insert-issuer-url-from-previous-command>

        APPLICATION_OBJECT_ID=<application-identity-enterprise-app-object-id>

        SERVICE_ACCOUNT_NAMESPACE=todo-app

        SERVICE_ACCOUNT_NAME=todoapp-sa
    
        cat <<EOF > params.json
        {
        "name": "kubernetes-federated-credential",
        "issuer": "${SERVICE_ACCOUNT_ISSUER}",
        "subject": "system:serviceaccount:${SERVICE_ACCOUNT_NAMESPACE}:${SERVICE_ACCOUNT_NAME}",
        "description": "Kubernetes service account federated credential",
        "audiences": [
            "api://AzureADTokenExchange"
        ]
        }
        EOF

        az ad app federated-credential create --id ${APPLICATION_OBJECT_ID} --parameters @params.json



#### 5. Set parameters
Parameters should have been set as part of "Goal 1". Yet set this one if has not been created:
- APP_DNS_NAME: DNS prefix to use for deploying apps later. This needs to be a unique name and DNS friendly

#### 6. Run the first deployment
Either by commiting changes to GitHub or running workflows [directly](https://docs.github.com/en/actions/managing-workflow-runs/manually-running-a-workflow), we can deploy our app resources

- Cluster setup workflow name: 'Trigger auto deployment for AKS app deployment'
- App deployment workflow name: 'Trigger auto deployment for AKS cluster setup'

#### 7. Run the first deployment
To connect to the AKS cluster, you need a user in the AD group defined in this parameter in "goal 1": AKS_ADMIN_GROUP_ID

With that user logged into Azure CLI, run the following command:
        
        az aks get-credentials -n <aks-cluster-name> -g <aks-resource-group>

        //you should get redirected to login page on next command
        kubectl get ns

Check the app is running by connecting to the cluster and running:

        kubectl get po -ntodo-app
If pods are not running, check the logs:

        kubectl logs -ntodo-app <pod-name>        