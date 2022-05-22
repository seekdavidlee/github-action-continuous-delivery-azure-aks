param prefix string
param appEnvironment string
param location string
param kubernetesVersion string = '1.23.3'
param subnetId string
param aksMSIId string

var stackName = '${prefix}${appEnvironment}'
var tags = {
  'stack-name': '${prefix}-api'
  'stack-environment': 'dev'
  'stack-owner': 'devteam1@contoso.com'
}

resource wks 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: stackName
  location: location
  tags: tags
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Note: AAD Pod Identity is disabled by default on clusters with Kubenet network plugin. 
// The NMI pods will fail to run with error AAD Pod Identity is not supported for Kubenet.
// https://github.com/Azure/aad-pod-identity/blob/master/website/content/en/docs/Configure/aad_pod_identity_on_kubenet.md

resource aks 'Microsoft.ContainerService/managedClusters@2022-01-02-preview' = {
  name: stackName
  location: location
  tags: tags
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${aksMSIId}': {}
    }
  }
  properties: {
    dnsPrefix: prefix
    kubernetesVersion: kubernetesVersion
    networkProfile: {
      networkPlugin: 'kubenet'
      serviceCidr: '10.250.0.0/16'
      dnsServiceIP: '10.250.0.10'
    }
    agentPoolProfiles: [
      {
        name: 'agentpool'
        type: 'VirtualMachineScaleSets'
        mode: 'System'
        osDiskSizeGB: 60
        count: 1
        minCount: 1
        maxCount: 3
        enableAutoScaling: true
        vmSize: 'Standard_B2ms'
        osType: 'Linux'
        osDiskType: 'Managed'
        vnetSubnetID: subnetId
        tags: tags
      }
    ]
    addonProfiles: {
      omsagent: {
        enabled: true
        config: {
          logAnalyticsWorkspaceResourceID: wks.id
        }
      }
    }
  }
}
