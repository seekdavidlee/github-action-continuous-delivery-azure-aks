# Introduction
This demo demonstrates Continuous Delivery (CD) for deploying .NET Web API Docker Container from Azure Container Registry (ACR) to Azure Kubernetes Service (AKS). 

## Prerequsites
There should already be an existing Azure Container Registry created following work from the [previous repo](https://github.com/seekdavidlee/github-action-continuous-delivery-apps). This Container Registry should already contain the Container image for mywebapp:0.1. 

Take note that the AKS and ACR must be created in the same Azure region!

Next, we need to create a resource group to host the VNET and the AKS cluster. We could technically reuse the resource group where ACR resides. If you are creating a new resource group, be sure the Service Principal defined in the AZURE_CREDENTIALS below has both Contributor and AcrPush roles. 

In order the script to use this resource group, on the resource group, there should be a 2 tags with key of stack-name and a value of a prefix followed by -api and another tag of stack-environment followed by a value of dev.

Run the following commands in Azure Cloud Shell or run locally if you already have Azure CLI installed for deploying the VNET. The source IP should be your home or office IP address. We want to make sure you are the only one that can access the web app. The prefix should be the STACK_NAME_TAG_PREFIX you have defined following work from the [previous repo](https://github.com/seekdavidlee/github-action-continuous-delivery-apps).

```
$sourceIP = ""
$prefix = ""
$networkingRg = ""
az deployment group create -n deploy-1 -g $networkingRg --template-file deployment/networking.bicep --parameters stackEnvironment=dev sourceIp=$sourceIP prefix=$prefix
```

Create a managed identity which will be assigned to AKS Cluster as its identity in the resource group. There should only be 1 managed identity in this resource group. The managed identity should be assigned AcrPull role in the resource group.

# Get Started
To create this demo in your environment, follow the steps below.

1. Fork this git repo. See: https://docs.github.com/en/get-started/quickstart/fork-a-repo
2. Clone your forked repo locally.
3. Create a branch locally. Do not push to remote yet.
4. Create the secret(s) in your github environment named dev.
5. Now you can push to remote. 
6. GitHub Action Workflow should kick off.
7. It will fail at the 'Deploy apps' step. 
![Failure message](/docs/failuremsg.png)
8. Run the following command in Cloud Shell or your local machine if you have Azure CLI installed. ``` ./CompleteSetup.ps1 -BUILD_ENV dev -STACK_NAME_TAG_PREFIX $STACK_NAME_TAG_PREFIX ```
9. Run-run failed jobs (not all jobs) 
![Rerun failed jobs](/docs/rerunfailedjobs.png)
10. Checkout the AKS Cluster. Under Services and ingresses, you should see a service with external ip.
11. Click on the external ip link and you should be navigated to Prometheus web interface.
12. Update your host file with the IP address with the web address web.contoso.com.

# Test
Now we are good to run the demo.

1. Launch the web browser and navigate to http://web.contoso.com/swagger. This should launch you into the API web interface.
2. In Cloud Shell, run the following ``` kubectl get pods -n myapps  ```. You should see one instance of mywebapp-...
3. We should now be able to do a quick load test. Run the following ``` .\LoadTest.ps1 -Intensity 500 -DayCounter -500 ```
4. Run the following query in Prometheus web interface ``` sum(rate(nginx_ingress_controller_requests{service="mywebapp"}[1m])) ```. Use the Graph tab which will make it easier to understand.
5. In Cloud Shell, run the following ``` kubectl get pods -n myapps  ```. You should see more than one instance of mywebapp-... which shows pod autoscaling is working with KEDA.

## Secrets
| Name | Comments |
| --- | --- |
| MS_AZURE_CREDENTIALS | <pre>{<br/>&nbsp;&nbsp;&nbsp;&nbsp;"clientId": "",<br/>&nbsp;&nbsp;&nbsp;&nbsp;"clientSecret": "", <br/>&nbsp;&nbsp;&nbsp;&nbsp;"subscriptionId": "",<br/>&nbsp;&nbsp;&nbsp;&nbsp;"tenantId": "" <br/>}</pre> |
| STACK_NAME_TAG_PREFIX | Use same value from [previous repo](https://github.com/seekdavidlee/github-action-continuous-delivery-apps) |