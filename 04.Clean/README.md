## 4. Destroy the environment after testing complete
<br/>

Run the following Azure CLI commands replacing the placeholders with resource group names for AKS and Container Apps: 

        az group delete -n <aks-resource-group>
        az group delete -n <aca-resource-group>