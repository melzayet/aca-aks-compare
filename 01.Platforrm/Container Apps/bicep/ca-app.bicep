param containerAppName string = 'todo-aca-cosmos'
param containerAppsEnvName string
param location string = resourceGroup().location

var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 4)
var databaseName = 'todoapp'
var containerName = 'tasks'

resource storage 'Microsoft.Storage/storageAccounts@2021-09-01' = {
  name: replace('${uniqueSuffix}sa', '-', '')
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    accessTier: 'Hot'
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
  }
}

var blobContainerName = 'dotnet-data-protection'

resource storageAccount_container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-02-01' = {
  name: '${storage.name}/default/${blobContainerName}'
}

resource cosmosAccount 'Microsoft.DocumentDB/databaseAccounts@2022-05-15' = {
  name: toLower('${uniqueSuffix}-todo')
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    consistencyPolicy: {
      defaultConsistencyLevel: 'Eventual'
    }
    locations: [
      {
        locationName: location
        failoverPriority: 0
        isZoneRedundant: false
      }
    ]
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    databaseAccountOfferType: 'Standard'
  }
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

@description('This is the built-in Contributor role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor')
resource storageContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {  
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: storage
}

resource userAssignedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: '${uniqueSuffix}-mi'
  location: location  
}

resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: storage
  name:guid(storage.id)
  properties: {
    roleDefinitionId: storageContributorRoleDefinition.id
    principalId: userAssignedIdentity.properties.principalId
    principalType:'ServicePrincipal'
  }
}

resource cosmosRBAC 'Microsoft.DocumentDB/databaseAccounts/sqlRoleDefinitions@2021-05-15' = {
  name: '736180af-7fbc-4c7f-9004-22735173c1c3'
  parent: cosmosAccount
  properties: {
    assignableScopes: [
     cosmosAccount.id
    ]
    permissions: [
      {
        dataActions: [
        'Microsoft.DocumentDB/databaseAccounts/readMetadata'
        'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/*'
        'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers/items/*'
        ]        
      }
    ]
    roleName: '${uniqueSuffix}-cosmos-rbac'
    type: 'CustomRole'
  }
}

resource cosmosRoleAssignment 'Microsoft.DocumentDB/databaseAccounts/sqlRoleAssignments@2021-05-15' = {
  name: '736180af-7fbc-4c7f-9004-22735173c1c4'
  parent: cosmosAccount
  properties: {
    principalId: userAssignedIdentity.properties.principalId
    roleDefinitionId: cosmosRBAC.id
    scope: cosmosAccount.id
  }
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
        targetPort: 80
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
          image: 'melzayet/todo-api:v0.5'
          name: 'todo-cosmos'
          probes: [
            {
              failureThreshold: 3
              tcpSocket: {                
                port: 80                
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              successThreshold: 1
              timeoutSeconds: 5
              type: 'Startup'
            }
            {
              failureThreshold: 3
              tcpSocket: {                
                port: 80                
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              successThreshold: 1
              timeoutSeconds: 5
              type: 'Liveness'
            }
          ]
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
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {   
            name: 'http-scaler'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }            
          }
        ]
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
        targetPort: 80
        external: true
      }   
    }
    template: {
      containers: [
        {
          image: 'melzayet/todo-ui:v0.5'
          name: 'todo-ui'
          probes: [
            {
              failureThreshold: 3
              tcpSocket: {                
                port: 80                
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              successThreshold: 1
              timeoutSeconds: 5
              type: 'Startup'
            }
            {
              failureThreshold: 3
              tcpSocket: {                
                port: 80                
              }
              initialDelaySeconds: 10
              periodSeconds: 10
              successThreshold: 1
              timeoutSeconds: 5
              type: 'Liveness'
            }
          ]
          env: [
            {
              name: 'apiEndpoint'
              value: 'https://${containerAppTodoAPI.properties.latestRevisionFqdn}/todoitems'
            }            
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
        rules: [
          {   
            name: 'http-scaler-ui'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }            
          }
        ]
      }
    }
  }
}
