param(
    [Parameter(Mandatory = $true)][string]$BUILD_ENV,
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
        throw "Unable to find resource by environment for $stackName!"
    }
        
    return $res
}
$ErrorActionPreference = "Stop"

$all = GetResource -stackName "$STACK_NAME_TAG_PREFIX-api" -stackEnvironment $BUILD_ENV
$aks = $all | Where-Object { $_.type -eq 'Microsoft.ContainerService/managedClusters' }
$AKS_RESOURCE_GROUP = $aks.resourceGroup
$AKS_NAME = $aks.name

$acr = GetResource -stackName "$STACK_NAME_TAG_PREFIX-shared-container-registry" -stackEnvironment $BUILD_ENV
$acrName = $acr.Name

$allMessages = (az aks check-acr -n $AKS_NAME -g $AKS_RESOURCE_GROUP --acr "$acrName.azurecr.io" 2>&1)
$allMessage = $allMessages -Join '`n'
Write-Host $allMessage
$acrErr = "An error has occured. Unable to verify if aks and acr are connected. Please run CompleteSetup.ps1 script now and when you are done, you can rerun this GitHub workflow."
if ($LastExitCode -ne 0) {
    throw $acrErr
}

if ($allMessage.ToUpper().Contains("FAILED")) {
    throw $acrErr
}
else {
    Write-Host $allMessage
}

$count = ($allMessage | Select-String -Pattern "SUCCEEDED" -AllMatches).Matches.Count
if ($count -lt 3) {
    Write-Host "SUCCEEDED Count = $count"
    throw $acrErr
}

az aks get-credentials --resource-group $AKS_RESOURCE_GROUP --name $AKS_NAME
Write-Host "::set-output name=aksName::$AKS_NAME"

$namespace = "myapps"
$testNamespace = kubectl get namespace $namespace
if (!$testNamespace ) {
    kubectl create namespace $namespace
}
else {
    Write-Host "Skip creating frontend namespace as it already exist."
}

$repoList = helm repo list --output json | ConvertFrom-Json

$foundHelmIngressRepo = ($repoList | Where-Object { $_.name -eq "ingress-nginx" }).Count -eq 1    
if (!$foundHelmIngressRepo ) {
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx   
}
else {
    Write-Host "Skip adding ingress-nginx repo with helm as it already exist."
}

$foundHelmKedaCoreRepo = ($repoList | Where-Object { $_.name -eq "kedacore" }).Count -eq 1
if (!$foundHelmKedaCoreRepo) {
    helm repo add kedacore https://kedacore.github.io/charts
}
else {
    Write-Host "Skip adding kedacore repo with helm as it already exist."
}

helm repo update

helm install -generate-name stable/Prometheus --namespace $namespace

helm install ingress-nginx ingress-nginx/ingress-nginx --namespace $namespace `
    --set controller.replicaCount=2 `
    --set controller.metrics.enabled=true `
    --set-string controller.podAnnotations."prometheus\.io/scrape"="true" `
    --set-string controller.podAnnotations."prometheus\.io/port"="10254"

helm install keda kedacore/keda -n $namespace

# $content = Get-Content .\Deployment\prometheus\kustomization.yaml
# $content = $content.Replace('$NAMESPACE', $namespace)
# Set-Content -Path ".\Deployment\prometheus\kustomization.yaml" -Value $content

# $content = Get-Content .\Deployment\prometheus\prometheus.yaml
# $content = $content.Replace('$NAMESPACE', $namespace)
# Set-Content -Path ".\Deployment\prometheus\prometheus.yaml" -Value $content

# kubectl apply --kustomize Deployment/prometheus -n $namespace
# if ($LastExitCode -ne 0) {
#     throw "An error has occured. Unable to apply prometheus directory."
# }

$content = Get-Content .\Deployment\mywebapp.yaml

$content = $content.Replace('$ACRNAME', $acrName)
$content = $content.Replace('$NAMESPACE', $namespace)

Set-Content -Path ".\mywebapp.yaml" -Value $content
kubectl apply -f ".\mywebapp.yaml" --namespace $namespace
if ($LastExitCode -ne 0) {
    throw "An error has occured. Unable to deploy mywebapp."
}

$content = Get-Content .\Deployment\ingress.yaml
$content = $content.Replace('$NAMESPACE', $namespace)
Set-Content -Path ".\ingress.yaml" -Value $content
$rawOut = (kubectl apply -f .\ingress.yaml --namespace $namespace 2>&1)
if ($LastExitCode -ne 0) {
    $errorMsg = $rawOut -Join '`n'
    if ($errorMsg.Contains("failed calling webhook") -and $errorMsg.Contains("validate.nginx.ingress.kubernetes.io")) {
        Write-Host "Attempting to recover from 'failed calling webhook' error."

        # See: https://pet2cattle.com/2021/02/service-ingress-nginx-controller-admission-not-found
        kubectl delete -A ValidatingWebhookConfiguration ingress-nginx-admission
        kubectl apply -f .\ingress.yaml --namespace $namespace
        if ($LastExitCode -ne 0) {
            throw "An error has occured. Unable to deploy external ingress."
        }
    }
    else {
        throw "An error has occured. Unable to deploy external ingress. $errorMsg "
    }    
}
else {
    Write-Host "Applied ingress config."    
}
