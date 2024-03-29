param location string = resourceGroup().location
param keyVaultNamePrefix string = 'cn-kv'
param aksClusterName string = 'aks-demo'
//principal id and object id are used interchangeably
param deployIdentityPrincipalId string
param adminGroupObjectId string

var appSubnetName = 'apps-subnet'
var infraSubnetName = 'infra-subnet'
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 4)
var databaseName = 'todoapp'
var containerName = 'tasks'

resource aksCluster 'Microsoft.ContainerService/managedClusters@2022-09-02-preview' = {
  name: aksClusterName
  location: location
  sku: {
    name: 'Basic'
    tier: 'Free'
  }
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    aadProfile: {      
      adminGroupObjectIDs: [
        adminGroupObjectId
      ]
      enableAzureRBAC: true
      managed: true
      tenantID: tenant().tenantId
    }
    addonProfiles: {
      azureKeyvaultSecretsProvider: {
        enabled: true
        
      
      }
    }
    dnsPrefix: aksClusterName
    agentPoolProfiles: [
      {
        availabilityZones: [
          '1', '2', '3'
        ]        
        count: 1
        enableAutoScaling: true
        maxCount: 2        
        minCount: 1
        mode: 'System'
        name: 'default'
        orchestratorVersion: '1.24.10'
        osDiskSizeGB: 128
        osDiskType:'Managed'
        osSKU:'Ubuntu'
        osType:'Linux'
        podSubnetID: virtualNetwork::appsSubnet.id
        type: 'VirtualMachineScaleSets'
        upgradeSettings: {
          maxSurge: '33%'
        }
        vmSize: 'standard_b2ms'
        vnetSubnetID: virtualNetwork::infraSubnet.id
      }
    ]  
    autoUpgradeProfile: {
      upgradeChannel: 'patch'
    }       
    disableLocalAccounts: true
    enableRBAC: true        
    kubernetesVersion: '1.24.10'    
    networkProfile: {
      dnsServiceIP: '192.168.100.10'
      dockerBridgeCidr: '172.17.0.1/16'     
      loadBalancerSku:'standard'       
      networkPlugin: 'azure'
      networkPolicy:'calico'
      outboundType:'loadBalancer'    
      serviceCidr: '192.168.100.0/24'
    }
    oidcIssuerProfile: {
      enabled: true
    }
    workloadAutoScalerProfile: {
      keda: {
        enabled: false
      }      
    }
  }
}

resource appMI 'Microsoft.ManagedIdentity/userAssignedIdentities@2022-01-31-preview' = {
  name: 'app-mi'
  location: location
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'aks-devtest-vnet'
  location: location
  properties: {
    subnets:[
      {
        name: infraSubnetName
        properties: {
          addressPrefix: '10.0.0.0/23'
          serviceEndpoints: [
            {
              locations: [
                location
              ]
              service: 'Microsoft.AzureCosmosDB'
            }
          ] 
        }
      }
      {
        name: appSubnetName
        properties: {
          addressPrefix: '10.0.2.0/23'       
          delegations: [
            {
              name: 'Microsoft.ContainerService/managedClusters'
              properties:{ 
                serviceName: 'Microsoft.ContainerService/managedClusters'
              }            
            }
          ]   
          serviceEndpoints: [
            {
              locations: [
                location
              ]
              service: 'Microsoft.AzureCosmosDB'
            }
          ]
        }
      }
    ]
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
  }
  resource infraSubnet 'subnets' existing = {
    name: infraSubnetName
  }

  resource appsSubnet 'subnets' existing = {
    name: appSubnetName
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2019-09-01' = {
  name: 'akv-${keyVaultNamePrefix}-${uniqueSuffix}'
  location: location
  properties: {
    enabledForTemplateDeployment: true
    enableSoftDelete: false
    enableRbacAuthorization: true
    tenantId: tenant().tenantId
    accessPolicies: [      
    ]
    sku: {
      name: 'standard'
      family: 'A'
    }
  }
}

resource keyVaultSecretCosmos 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: keyVault
  name: 'CosmosEndpoint'
  properties: {
    value: 'https://${cosmosAccount.name}.documents.azure.com:443/'
  }
}

resource keyVaultSecretStorage 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: keyVault
  name: 'DataProtectionEndpoint'
  properties: {
    value: 'https://${storage.name}.blob.${environment().suffixes.storage}/${blobContainerName}/keys'
  }
}

resource keyVaultSecretMI 'Microsoft.KeyVault/vaults/secrets@2019-09-01' = {
  parent: keyVault
  name: 'MiClientID'
  properties: {
    value: appMI.properties.clientId
  }
}

@description('This is the built-in Contributor role. See https://docs.microsoft.com/azure/role-based-access-control/built-in-roles#contributor')
resource storageContributorRoleDefinition 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {  
  name: 'ba92f5b4-2d11-453d-a403-e96b0029c9fe'
  scope: storage
}

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
    isVirtualNetworkFilterEnabled: true
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
    virtualNetworkRules: [
      {
        id: virtualNetwork::appsSubnet.id
        ignoreMissingVNetServiceEndpoint: false
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

resource storageRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: storage
  name:guid(storage.id,storageContributorRoleDefinition.id)
  properties: {
    roleDefinitionId: storageContributorRoleDefinition.id
    principalId: appMI.properties.principalId
    principalType:'ServicePrincipal'
  }
}

resource csiKvRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: keyVault
  name:guid(keyVault.id, '4633458b-17de-408a-b874-0445c86b69e6')
  properties: {
    // KV Secretsuser
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions/', '4633458b-17de-408a-b874-0445c86b69e6')
    principalId: appMI.properties.principalId
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
  name: '736180af-7fbc-4c7f-9004-22735173c2c4'
  parent: cosmosAccount
  properties: {
    principalId: appMI.properties.principalId
    roleDefinitionId: cosmosRBAC.id
    scope: cosmosAccount.id
  }
}


resource aksRbacAdminRoleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
  scope: aksCluster
  name: guid(aksCluster.id, deployIdentityPrincipalId)
  properties: {
    // AKS RBAC Cluster Admin
    roleDefinitionId: resourceId('Microsoft.Authorization/roleDefinitions/', 'b1ff04bb-8a4e-4dc4-8eb5-8693973ce19b')  
    principalId: deployIdentityPrincipalId
    principalType:'ServicePrincipal'
  }
}

output kvName string = keyVault.name


