## 2. Deploying to AKS
<br/>

### 1. Fork this repository (if not already)
This will allow you to set secret and run your own workflows. Click [here](https://github.com/melzayet/azure-cn-depicted/fork) to fork.


### 2. Run the first deployment
Either by commiting changes to GitHub or running workflows [directly](https://docs.github.com/en/actions/managing-workflow-runs/manually-running-a-workflow), we can deploy our app resources

Run the following workflows:
- Cluster setup workflow name: 'Trigger auto deployment for AKS app deployment'
- App deployment workflow name: 'Trigger auto deployment for AKS cluster setup'

### 4. Check the app is running
Access the application using http://<APP_DNS_NAME>.<region>.cloudapp.azure.com

To connect to the AKS cluster, you need a user in the AD group defined in this parameter during cluster deployment": AKS_ADMIN_GROUP_ID

With that user logged into Azure CLI, run the following command:
```        
az aks get-credentials -n <aks-cluster-name> -g <aks-resource-group>

kubelogin convert-kubeconfig -l azurecli  

kubectl get ns
```

Check the app is running by connecting to the cluster and running:

        kubectl get po -ntodo-app

If pods are not running, check the logs:

        kubectl logs -ntodo-app <pod-name>        