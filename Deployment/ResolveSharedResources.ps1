param(
    [Parameter(Mandatory = $true)][string]$BUILD_ENV,
    [Parameter(Mandatory = $true)][string]$PREFIX,
    [Parameter(Mandatory = $true)][string]$STACK_NAME_TAG_PREFIX)

function GetResource([string]$stackName, [string]$stackEnvironment) {
    $platformRes = (az resource list --tag stack-name=$stackName | ConvertFrom-Json)
    if (!$platformRes) {
        throw "Unable to find eligible $stackName resource!"
    }
    if ($platformRes.Length -eq 0) {
        throw "Unable to find 'ANY' eligible $stackName resource!"
    }
    
    $res = ($platformRes | Where-Object { $_.tags.'stack-environment' -eq $stackEnvironment })
    if (!$res) {
        throw "Unable to find $stackName resource by $stackEnvironment environment!"
    }
    
    return $res
}

$ErrorActionPreference = "Stop"

$networkResources = GetResource -stackName "$STACK_NAME_TAG_PREFIX-networking" -stackEnvironment $BUILD_ENV
$vnet = $networkResources | Where-Object { !$_.name.EndsWith('-nsg') -and $_.name.Contains('-pri-') }
$vnetRg = $vnet.resourceGroup
$vnetName = $vnet.name
$location = $vnet.location
Write-Host "::set-output name=location::$location"

$subnets = (az network vnet subnet list -g $vnetRg --vnet-name $vnetName | ConvertFrom-Json)
if (!$subnets) {
    throw "Unable to find eligible Subnets from Virtual Network $vnetName!"
}          
$subnetId = ($subnets | Where-Object { $_.name -eq "aks" }).id
if (!$subnetId) {
    throw "Unable to find aks Subnet resource!"
}
Write-Host "::set-output name=subnetId::$subnetId"

# This is the rg where the application should be deployed
$groups = az group list --tag stack-environment=$BUILD_ENV | ConvertFrom-Json
$appResourceGroup = ($groups | Where-Object { $_.tags.'stack-name' -eq "$PREFIX-api" }).name
Write-Host "::set-output name=appResourceGroup::$appResourceGroup"

# Also resolve managed identity to use
$identity = az identity list -g $appResourceGroup | ConvertFrom-Json
$mid = $identity.id
Write-Host "::set-output name=managedIdentityId::$mid"