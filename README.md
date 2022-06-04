# Introduction
This demo demonstrates Continuous Delivery (CD) for deploying .NET Web API Docker Container from Azure Container Registry (ACR) to Azure Kubernetes Service (AKS). 

## Prerequsites
There should already be an existing Azure Container Registry created following work from the [previous repo](https://github.com/seekdavidlee/github-action-continuous-delivery-apps). This Container Registry should already contain the Container image for mywebapp:0.1.

Next, we need to create a resource group to host the VNET and the AKS cluster. We could technically reuse the resource group where ACR resides. If you are creating a new resource group, be sure the Service Principal defined in the AZURE_CREDENTIALS below has both Contributor and AcrPush roles. 

In order the script to use this resource group, on the resource group, there should be a 2 tags with key of stack-name and a value of a prefix followed by -api and another tag of stack-environment followed by a value of dev.

Run the following commands in Azure Cloud Shell or run locally if you already have Azure CLI installed for deploying the VNET. The source IP should be your home or office IP address. We want to make sure you are the only one that can access the web app. The prefix should be the STACK_NAME_TAG_PREFIX you have defined following work from the [previous repo](https://github.com/seekdavidlee/github-action-continuous-delivery-apps).

```
$sourceIP = ""
$prefix = ""
$networkingRg = ""
az deployment group create -n deploy-1 -g $networkingRg --template-file deployment/networking.bicep --parameters stackEnvironment=dev sourceIp=$sourceIP prefix=$prefix
```

Create a Managed identity which will be assigned to AKS Cluster as its identity.