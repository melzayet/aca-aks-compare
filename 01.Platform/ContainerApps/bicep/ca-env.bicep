param containerAppsEnvName string
param location string = resourceGroup().location
param logAnalyticsWorkspaceName string= '${containerAppsEnvName}-la'
param appInsightsName string = '${containerAppsEnvName}-ai'

var appSubnetName = 'apps-subnet'
var infraSubnetName = 'infra-subnet'
var uniqueSuffix = substring(uniqueString(resourceGroup().id), 0, 4)

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
    isVirtualNetworkFilterEnabled: true
    capabilities: [
      {
        name: 'EnableServerless'
      }
    ]
    virtualNetworkRules: [
      {
        id: virtualNetwork::infraSubnet.id
        ignoreMissingVNetServiceEndpoint: false
      }
    ]
    databaseAccountOfferType: 'Standard'
  }
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

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2019-11-01' = {
  name: 'aca-devtest-vnet'
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
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
  }
  resource infraSubnet 'subnets' existing = {
    name: infraSubnetName
  }

  resource appsSubnet 'subnets' existing = {
    name: appSubnetName
  }
}


resource logAnalyticsWorkspace 'Microsoft.OperationalInsights/workspaces@2022-10-01' = {
  name: logAnalyticsWorkspaceName
  location: location
  properties: any({
    retentionInDays: 30
    features: {
      searchVersion: 1
    }
    sku: {
      name: 'PerGB2018'
    }
  })
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: { 
    Application_Type: 'web'
  }
}

resource containerAppsEnv 'Microsoft.App/managedEnvironments@2022-06-01-preview' = {
  name: containerAppsEnvName
  location: location
  sku: {
    name: 'Consumption'
  }
  properties: {    
    daprAIInstrumentationKey: appInsights.properties.InstrumentationKey
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalyticsWorkspace.properties.customerId
        sharedKey: logAnalyticsWorkspace.listKeys().primarySharedKey
      }
    }
    zoneRedundant: true
    vnetConfiguration: {
      infrastructureSubnetId: virtualNetwork::infraSubnet.id
      runtimeSubnetId: virtualNetwork::appsSubnet.id
      internal: false
      dockerBridgeCidr: '172.17.0.1/16'
      platformReservedCidr: '192.168.100.0/24'
      platformReservedDnsIP: '192.168.100.10'
      outboundSettings: { 
        outBoundType: 'LoadBalancer'
      }
    }
  }
}

output name string = containerAppsEnv.name
output cappsEnvId string = containerAppsEnv.id
output appInsightsInstrumentationKey string = appInsights.properties.InstrumentationKey
output defaultDomain string = containerAppsEnv.properties.defaultDomain
