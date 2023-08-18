@description('Admin username')
param adminUsername string

@description('Admin password')
@secure()
param adminPassword string

@description('VM Prefix')
param vmNamePrefix string = 'BackendVM'

@description('Location for all resources')
param location string = resourceGroup().location

@description('Size of virtual machine')
param vmSize string = 'Standard_D2s_v3'

var availabilitySetName = 'AvSet'
var storageAccountType = 'Standard_LRS'
var storageAccountName = uniqueString(resourceGroup().id)
var virtualNetworkName = 'vNet'
var subnetName = 'subnet'
var loadBalancerName = 'ibl'
var loadBalancerFrontendIpConfigurationName = 'LoadBalancerFrontend'
var loadBalancerBackendAddressPoolName = 'BackendPool1'
var loadBalancerProbeName = 'lbprobe'
var networkInterfaceName = 'nic'
var numberOfInstances = 2
var subnetRef = resourceId('Microsoft.Network/virtualNetworks/subnets', virtualNetworkName, subnetName)
var loadBalanceFrontendIpConfigurationRef = resourceId('Microsoft.Network/loadBalancers/frontendIpConfigurations', loadBalancerName, loadBalancerFrontendIpConfigurationName)
var loadBalancerBackendPoolRef = resourceId('Microsoft.Network/loadBalancers/backendAddressPools', loadBalancerName, loadBalancerBackendAddressPoolName)
var loadBalancerProbeRef = resourceId('Microsoft.Network/loadBalancers/probes', loadBalancerName, loadBalancerProbeName)

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-08-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: storageAccountType
  }
  kind: 'StorageV2'
}

resource availabilitySet 'Microsoft.Compute/availabilitySets@2022-11-01' = {
  name: availabilitySetName
  location: location
  sku: {
    name: 'Aligned'
  }
  properties: {
    platformUpdateDomainCount: 2
    platformFaultDomainCount: 2
  }
}

resource virtualNetwork 'Microsoft.Network/virtualNetworks@2022-05-01' = {
  name: virtualNetworkName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        '10.0.0.0/16'
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.2.0/24'
        }
      }
    ]
  }
}

resource loadBalancer 'Microsoft.Network/loadBalancers@2021-05-01' = {
  name: loadBalancerName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    frontendIPConfigurations: [
      {
        properties: {
          subnet: {
            id: subnetRef
          }
          privateIPAddress: '10.0.2.6'
          privateIPAllocationMethod: 'Static'
        }
        name: loadBalancerFrontendIpConfigurationName
      }
    ]
    backendAddressPools: [
      {
        name: loadBalancerBackendAddressPoolName
      }
    ]
    probes: [
      {
        properties: {
          port: 80
          protocol: 'Tcp'
          intervalInSeconds: 15
          numberOfProbes: 2
        }
        name: loadBalancerProbeName
      }
    ]
    loadBalancingRules: [
      {
        properties: {
          frontendPort: 80
          backendPort: 80
          protocol: 'Tcp' 
          idleTimeoutInMinutes: 15
          frontendIPConfiguration: {
            id: loadBalanceFrontendIpConfigurationRef
          }
          backendAddressPool: {
            id: loadBalancerBackendPoolRef
          }
          probe: {
            id: loadBalancerProbeRef
          }
        }
      }
    ]    
  }
  dependsOn: [
    virtualNetwork
  ]
}

resource networkInterface 'Microsoft.Network/networkInterfaces@2022-05-01' = [for i in range(0, numberOfInstances):{
  name: '${networkInterfaceName}${i}'
  location: location
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          privateIPAllocationMethod: 'Dynamic'
          subnet: {
            id: subnetRef
          }
          loadBalancerBackendAddressPools: [
            {
              id: loadBalancerBackendPoolRef
            }
          ]
        }
      }
    ]
  }
  dependsOn: [
    virtualNetwork
    loadBalancer
  ]
}]

resource virtualMachine 'Microsoft.Compute/virtualMachines@2021-11-01' = [for i in range(0, numberOfInstances): {
  name: '${vmNamePrefix}${i}'
  location: location
  properties: {
    availabilitySet: {
      id: availabilitySet.id
    }
    hardwareProfile: {
      vmSize: vmSize  
    }
    osProfile: {
      computerName: '${vmNamePrefix}${i}'
      adminUsername: adminUsername
      adminPassword: adminPassword
    }
    storageProfile: {
      imageReference: {
        publisher: 'Canonical'
        offer: '0001-com-ubuntu-server-jammy'
        sku: '22_04-lts-gen2'
        version: 'latest'
      }
      osDisk: {
        createOption: 'FromImage'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: networkInterface[i].id
        }
      ]
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
        storageUri: storageAccount.properties.primaryEndpoints.blob
      }
    }
  }
}]
