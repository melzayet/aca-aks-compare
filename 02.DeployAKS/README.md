## 2. Deploying to AKS
<br/>

### 1. Fork this repository (if not already)
This will allow you to set secret and run your own workflows. Click [here](https://github.com/melzayet/azure-cn-depicted/fork) to fork.


### 2. Setup app identity
If you followed "1. Build AKS and Container Apps environments" steps, the deployment identity was created, and it was given AKS cluster admin role. 

The app identity was also created. Yet, you need to give it now a federated credential as follows. Use a Linux command line to run those AZ CLI commands:

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


### 3. Run the first deployment
Either by commiting changes to GitHub or running workflows [directly](https://docs.github.com/en/actions/managing-workflow-runs/manually-running-a-workflow), we can deploy our app resources

- Cluster setup workflow name: 'Trigger auto deployment for AKS app deployment'
- App deployment workflow name: 'Trigger auto deployment for AKS cluster setup'

### 4. Check the app is running
To connect to the AKS cluster, you need a user in the AD group defined in this parameter in "goal 1": AKS_ADMIN_GROUP_ID

With that user logged into Azure CLI, run the following command:
        
        az aks get-credentials -n <aks-cluster-name> -g <aks-resource-group>

        //you should get redirected to login page on next command
        kubectl get ns

Check the app is running by connecting to the cluster and running:

        kubectl get po -ntodo-app
If pods are not running, check the logs:

        kubectl logs -ntodo-app <pod-name>        