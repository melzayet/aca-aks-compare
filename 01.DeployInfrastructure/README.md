## 1. Build AKS and Container Apps environments
<br/>

### 1. Fork this repository
This will allow you to set secret and run your own workflows. Click [here](https://github.com/melzayet/azure-cn-depicted/fork) to fork.

### 2. Setup deployment and app AAD identities
Deployment identity is what GitHub will use to deploy to Azure. Follow the steps [here](https://learn.microsoft.com/en-us/azure/active-directory/develop/workload-identity-federation-create-trust?pivots=identity-wif-apps-methods-azp#github-actions) to create this identity. Please make a note of the Azure AD app's Client ID and the Object ID of the associated Enterprise app.

Please make a note of the Azure AD deployment identity Client ID, and the Object ID of the associated Enterprise app.

Create a AD Group and put your user as a member in this group. This group will be set as admin on the AKS cluster.

### 3. Setup deployment target
Create an Azure Resource Group to hold the AKS infrastructure and app resources. It's also a scope for permissions. Make the deployment identity created in step 4, as an Owner for this resource group. Please make a note of the resource group name.

Repeat the same steps for Container Apps.

        az group create -n <aks-resource-group> -l <your-preferred-region>
        az group create -n <aca-resource-group> -l <your-preferred-region>

For example

        az group create -n aks -l westeurope
        az group create -n aca -l westeurope

Make the Deployment Identity an Owner on both resource groups, replacing the placeholders. Deployment Identity object ID can be found in the portal under Enterprise Applications blade.

        az role assignment create --role Owner --assignee <deployment-identity-object-id-here> --scope /subscriptions/<subscription-id-here>/resourceGroups/<resource-group-name-here>

Make sure the command is run on both resource groups for AKS and Container Apps

### 4. Set GitHub Secrets
Set the following GitHub secrets using the steps [here](https://docs.github.com/en/actions/security-guides/encrypted-secrets#creating-encrypted-secrets-for-a-repository):

- AKS_ADMIN_GROUP_ID: ID of an Azure AD Group that can access and administrate the AKS cluster if needed
- AKS_RG: The resource group name for AKS noted in step 3
- DEPLOY_IDENTITY_CLIENT_ID: The Client ID for Deploy Identity created in step 3.
- DEPLOY_IDENTITY_PRINCIPAL_ID: The Object ID for Deploy Identity's Enterprise App in Azure AD
- SUBSCRIPTION_ID: The Subscription ID to deploy infrastructure and where resource group(s) were created
- TENANT_ID: Azure AD Tenant ID
- ACA_RG: The resource group name for Container Apps noted in step 3
- ACA_ENV_NAME: A name for Container Apps environment
- APP_DNS_NAME:  DNS prefix attached to public IP to use for accessing the app later. This needs to be a unique name and DNS friendly. e.g. myapp

### 5. Run the first deployment
Run the following GitHub workflows [directly](https://docs.github.com/en/actions/managing-workflow-runs/manually-running-a-workflow), so we can deploy our infrasructure resources

Click Run workflow for those two workflows:
![Trigger Workflow](/images/trigger-workflow.png)

- AKS workflow name: 'Trigger auto deployment for AKS cluster deployment'
- Container Apps workflow name: 'Trigger auto deployment for Azure Container Apps'

