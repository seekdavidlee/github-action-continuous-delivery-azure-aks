param(
    
    [Parameter(Mandatory = $true)][string]$BUILD_ENV,
    [Parameter(Mandatory = $true)][string]$STACK_NAME_TAG_PREFIX)

$ErrorActionPreference = "Stop"

$groups = az group list --tag stack-environment=$BUILD_ENV | ConvertFrom-Json
$resourceGroupName = ($groups | Where-Object { $_.tags.'stack-name' -eq "$STACK_NAME_TAG_PREFIX-api" -and $_.tags.'stack-environment' -eq $BUILD_ENV })[0].name
$aks = (az resource list -g $resourceGroupName --resource-type "Microsoft.ContainerService/managedClusters" | ConvertFrom-Json)[0]
az aks get-credentials -n $aks.name -g $resourceGroupName --overwrite-existing
$acr = (az resource list --tag stack-name="$STACK_NAME_TAG_PREFIX-shared-container-registry" | ConvertFrom-Json)[0]
$acrName = $acr.name
az aks update -n $aks.name -g $resourceGroupName --attach-acr $acrName
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to update aks with acr."
}

$aksName = $aks.name
az aks check-acr -n $aksName -g $resourceGroupName --acr "$acrName.azurecr.io"
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to verify if aks and acr are connected."
}