@description('Name of new or existing vnet to which Azure Bastion should be deployed')
param vnetName string = 'vNet'

@description('Ip prefix for available addresses in vnet address space')
param vnetIpPrefix string = '10.0.0.0/16'

@description('Specify whether to provision a new vnet or deploy to an existing one')
@allowed([
  'new'
  'existing'
])
param vnetNewOrExisting string = 'existing'

@description('Bastion subnet IP prefix MUST be within vnet IP prefix address space')
param bastionSubnetIpPrefix string = '10.0.1.0/26'

@description('Name of the Azure Bastion resource')
param bastionHostName string = 'vnet-bastion'

@description('Azure region for Bastion and Virtual network')
param location string = resourceGroup().location

var publicIpAddressName = '${bastionHostName}-pip'
var bastionSubnetName = 'AzureBastionSubnet'

resource publicIp 'Microsoft.Network/publicIPAddresses@2022-01-01' = {
  name: publicIpAddressName
  location: location
  sku: {
    name: 'Standard'
  }
  properties: {
    publicIPAllocationMethod: 'Static'
  }
}

resource newVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' = if (vnetNewOrExisting == 'new') {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
       addressPrefixes: [
        vnetIpPrefix
       ]
    }
    subnets: [
      {
        name: bastionSubnetName
        properties: {
          addressPrefix: bastionSubnetIpPrefix
        }
      }
    ]
  }
}

resource existingVirtualNetwork 'Microsoft.Network/virtualNetworks@2022-01-01' existing = if (vnetNewOrExisting == 'existing') {
  name: vnetName
}

resource subnet 'Microsoft.Network/virtualNetworks/subnets@2022-01-01' = if (vnetNewOrExisting == 'existing') {
  parent: existingVirtualNetwork
  name: bastionSubnetName
  properties: {
    addressPrefix: bastionSubnetIpPrefix
  }
}

resource bastionHost 'Microsoft.Network/bastionHosts@2022-01-01' = {
  name: bastionHostName
  location: location
  dependsOn: [
    newVirtualNetwork
    existingVirtualNetwork
  ]
  properties: {
    ipConfigurations: [
      {
        name: 'IpConf'
        properties: {
          publicIPAddress: {
            id: publicIp.id
          }
          subnet: {
            id: subnet.id
          }
        }
      }
    ]
  }
}
