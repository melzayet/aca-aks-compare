param containerAppsEnvName string
param location string = resourceGroup().location
param logAnalyticsWorkspaceName string= '${containerAppsEnvName}-la'
param appInsightsName string = '${containerAppsEnvName}-ai'

var appSubnetName = 'apps-subnet'
var infraSubnetName = 'infra-subnet'


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
        }
      }
      {
        name: appSubnetName
        properties: {
          addressPrefix: '10.0.2.0/23'
        }
      }
    ]
  }
}

resource infraSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' = {
  name: infraSubnetName
  parent: virtualNetwork
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

resource appsSubnet 'Microsoft.Network/virtualNetworks/subnets@2022-05-01' = {
  name: appSubnetName
  parent: virtualNetwork
  properties: {
    addressPrefix: '10.0.2.0/23'
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
