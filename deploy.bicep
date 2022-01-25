//
// Minecraft Bedrock Server container deploy template
// private link version
//

// parameters
@description('base name for azure resources')
param baseName string = 'beserver'

@description('virtual network CIDR')
param addressPrefix string = '192.168.0.0/24'

@description('vm size')
param vmSize string = 'Standard_b1s'

@description('nfs storage sku')
@allowed([
  'Premium_LRS'
  'Standard_LRS'
])
param storageSku string = 'Standard_LRS'

@description('nfs storage kind')
@allowed([
  'BlockBlobStorage'
  'StorageV2'
])
param storageKind string = 'StorageV2'

@description('my public ip address')
param myIp string = ''

@description('administrator user name')
param adminUsername string = 'azureuser'

@description('administrator password')
@secure()
param adminPassword string

@description('ignition config file for flatcar')
param customData string = ''

// variables
var subnetName = 'snet-${baseName}'
var vnetName = 'vnet-${baseName}'
var nsgName = 'nsg-${subnetName}'
var pipName = 'ip-${baseName}'
var nicName = 'nic-${baseName}'
var vmName = 'vm-${baseName}'
var pepName = 'pep-${baseName}'

var blobContainerName = 'minecraftdata'

var myRegion = resourceGroup().location

// network security group for subnet
resource nsg 'Microsoft.Network/networkSecurityGroups@2021-05-01' = {
  name: nsgName
  location: myRegion
  properties: {
    securityRules: [
      {
        name: 'AllowMinecraftInbound'
        properties: {
          description: 'Allow inbound access on Minecraft'
          protocol: 'Udp'
          sourcePortRange: '*'
          destinationPortRange: '19132'
          sourceAddressPrefix: '*'
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 100
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
      {
        name: 'AllowSshInbound'
        properties: {
          description: 'Allow inbound access on TCP 22'
          protocol: 'Tcp'
          sourcePortRange: '*'
          destinationPortRange: '22'
          sourceAddressPrefix: empty(myIp) ? 'Internet' : myIp
          destinationAddressPrefix: '*'
          access: 'Allow'
          priority: 1000
          direction: 'Inbound'
          sourcePortRanges: []
          destinationPortRanges: []
          sourceAddressPrefixes: []
          destinationAddressPrefixes: []
        }
      }
    ]
  }
}

// virtual network
resource vnet 'Microsoft.Network/virtualNetworks@2021-05-01' = {
  name: vnetName
  location: myRegion
  properties: {
    addressSpace: {
      addressPrefixes: [
        addressPrefix
      ]
    }
    subnets: [
      {
        name: subnetName
        properties: {
          privateEndpointNetworkPolicies: 'Disabled'
          addressPrefix: addressPrefix
          networkSecurityGroup: {
            id: nsg.id
          }
        }
      }
    ]
  }
}

// storage account (supported NFS)
resource st 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: 'st${uniqueString(resourceGroup().id)}'
  location: myRegion
  sku: {
    name: storageSku
  }
  kind: storageKind
  properties: {
    isNfsV3Enabled: true
    isHnsEnabled: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    networkAcls: {
      bypass: 'AzureServices'
      defaultAction: 'Deny'
      ipRules: empty(myIp) ? [] : [
        {
          value: myIp
          action: 'Allow'
        }
      ]
    }
    supportsHttpsTrafficOnly: true
    accessTier: 'Hot'
  }
}

resource blob 'Microsoft.Storage/storageAccounts/blobServices@2021-06-01' = {
  parent: st
  name: 'default'
}

resource blob_container 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-06-01' = {
  parent: blob
  name: blobContainerName // container (share) name
  properties: {
    publicAccess: 'None'
  }
}

// private end point for blob storage
resource pep 'Microsoft.Network/privateEndpoints@2021-05-01' = {
  name: pepName
  location: myRegion
  properties: {
    privateLinkServiceConnections: [
      {
        name: pepName
        properties: {
          privateLinkServiceId: st.id
          groupIds: [
            'blob'
          ]
        }
      }
    ]
    subnet: {
      id: '${vnet.id}/subnets/${subnetName}'
    }
  }
}

// dns zone
resource dns 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.blob.core.windows.net'
  location: 'global'
}

// link virtual network
resource dnslink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: dns
  name: 'vnetlink'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
}

// private end point dns zone group
resource pepg 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2021-05-01' = {
  parent: pep
  name: 'group1'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'privatelink_blob_core_windows_net'
        properties: {
          privateDnsZoneId: dns.id
        }
      }
    ]
  }
}

// public ip address for vm
resource pip 'Microsoft.Network/publicIPAddresses@2021-05-01' = {
  name: pipName
  location: myRegion
  sku: {
    name: 'Basic'
  }
  properties: {
    publicIPAddressVersion: 'IPv4'
    publicIPAllocationMethod: 'Static'
    idleTimeoutInMinutes: 4
  }
}

// network interface for vm
resource nic 'Microsoft.Network/networkInterfaces@2021-05-01' = {
  name: nicName
  location: myRegion
  properties: {
    ipConfigurations: [
      {
        name: 'ipconfig1'
        properties: {
          subnet: {
            id: '${vnet.id}/subnets/${subnetName}'
          }
          privateIPAllocationMethod: 'Dynamic'
          privateIPAddressVersion: 'IPv4'
          publicIPAddress: {
            id: pip.id
          }
        }
      }
    ]
  }
}

// virtual machine
resource vm 'Microsoft.Compute/virtualMachines@2021-07-01' = {
  name: vmName
  location: myRegion
  plan: {
    name: 'stable'
    publisher: 'kinvolk'
    product: 'flatcar-container-linux-free'
  }
  properties: {
    hardwareProfile: {
      vmSize: vmSize
    }
    storageProfile: {
      osDisk: {
        createOption: 'FromImage'
        managedDisk: {
          storageAccountType: 'StandardSSD_LRS'
        }
      }
      imageReference: {
        publisher: 'kinvolk'
        offer: 'flatcar-container-linux-free'
        sku: 'stable'
        version: 'latest'
      }
    }
    networkProfile: {
      networkInterfaces: [
        {
          id: nic.id
        }
      ]
    }
    osProfile: {
      computerName: vmName
      adminUsername: adminUsername
      adminPassword: adminPassword
      customData: empty(customData) ? loadFileAsBase64('./config.json') : customData
    }
    diagnosticsProfile: {
      bootDiagnostics: {
        enabled: true
      }
    }
    userData: base64('${st.name},${blobContainerName}') // set storage account name and container name to VM meta data
  }
  dependsOn: [
    pepg
  ]
}
