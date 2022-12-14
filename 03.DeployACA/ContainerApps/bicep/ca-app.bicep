param containerAppName string = 'todo-aca-cosmos'
param containerAppsEnvName string
param location string = resourceGroup().location
param cosmosAccountName string
var databaseName = 'todoapp'
var containerName = 'tasks'

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' existing = {
  name: cosmosAccountName
}

resource database 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-05-15' = {
  parent: cosmosAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}
resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-05-15' = {
  parent: database
  name: containerName
  properties: {
    resource: {
      id: containerName
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
    }
  }
}
resource containerAppsEnv  'Microsoft.App/managedEnvironments@2022-06-01-preview' existing = {
  name: containerAppsEnvName
}

resource containerAppTodoAPI 'Microsoft.App/containerApps@2022-06-01-preview' ={
  name: containerAppName
  location: location
  identity:{
    type: 'UserAssigned'
    userAssignedIdentities: {
      '/subscriptions/${subscription().subscriptionId}/resourceGroups/${resourceGroup().name}/providers/Microsoft.ManagedIdentity/userAssignedIdentities/${userAssignedIdentity.name}': {}
    }
  }
  properties:{
    managedEnvironmentId: containerAppsEnv.id  
    configuration: {
      ingress: {
        targetPort: 8080
        external: true
      } 
      secrets: [
        {
          name: 'blob-endpoint'
          value: 'https://${storage.name}.blob.${environment().suffixes.storage}/${blobContainerName}/keys'
        }
        {
          name: 'cosmos-endpoint'
          value: 'https://${cosmosAccount.name}.documents.azure.com:443/'
        }
        {
          name: 'mi-client-id'
          value: userAssignedIdentity.properties.clientId
        }
      ]
    }
    template: {
      containers: [
        {
          image: 'melzayet/todo-api:v3.2'
          name: 'todo-cosmos'   
          env: [
            {
              name: 'DataProtectionEndpoint'
              secretRef: 'blob-endpoint'

            }
            {
              name: 'DatabaseName'
              value: databaseName

            }
            {
              name: 'ContainerName'
              value: containerName

            }
            {
              name: 'CosmosEndpoint'
              secretRef: 'cosmos-endpoint'

            }
            {
              name: 'AZURE_CLIENT_ID'
              secretRef: 'mi-client-id'

            }
          ]
        }
        {
          image: 'melzayet/reverseproxy:3000'
          name: 'todo-api-proxy'                    
        }        
      ]
      scale: {
        minReplicas: 1
      }
    }
  }
}

resource containerAppTodoUI 'Microsoft.App/containerApps@2022-06-01-preview' ={
  name: '${containerAppName}-ui'
  location: location
  properties:{
    managedEnvironmentId: containerAppsEnv.id  
    configuration: {
      ingress: {
        targetPort: 8080
        external: true
      }   
    }
    template: {
      containers: [
        {
          image: 'melzayet/todo-ui:v3.0'
          name: 'todo-ui'        
          env: [
            {
              name: 'apiEndpoint'
              value: 'https://${containerAppTodoAPI.properties.latestRevisionFqdn}/todo'
            }            
          ]
        }
        {
          image: 'melzayet/reverseproxy:5000'
          name: 'todo-ui-proxy'                   
          
        }
      ]     
    }
  }
}
