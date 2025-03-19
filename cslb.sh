# Sign in to Azure CLI
Az login --tenant <your tenant ID here> --use-device-code

###########
### Initial setup, subscription B
###########

# Change subscription to Azure Subscription B (<subscription B ID>) where the backend virtual network and load balancer pool will reside
az account set --name '<subscription B name>'

# Create a resource group in Azure Subscription B 
az group create --name 'rg-cslb-back' --location centralus

# Create a backend vnet in subscription B
az network vnet create -g rg-cslb-back -n vnet-back --address-prefix 10.2.0.0/16 --subnet-name back --subnet-prefixes 10.2.0.0/24

###########
### Initial setup, subscription A
###########

# Change subscription to Azure Subscription A (<subscription A ID>) where the load balancer and front end will reside
az account set --name '<subscription A name>'

# Create a resource group in Azure Subscription A 
az group create --name 'rg-cslb-front' --location centralus

###########
### Load balancer setup, subscription A
###########

# Create a load balancer with a frontend public IP address in subscription A
az network lb create --resource-group rg-cslb-front --name cslb --sku Standard --frontend-ip-name ip-front --tags 'IsRemoteFrontend=true'

# Create a back end pool in the vnet of Subscription B
az network lb address-pool create --address-pool-name pool-back --lb-name cslb --resource-group rg-cslb-front --vnet '/subscriptions/<subscription B ID>/resourceGroups/rg-cslb-back/providers/Microsoft.Network/virtualNetworks/vnet-back' --sync-mode Automatic

# Create a health probe
az network lb probe create --resource-group rg-cslb-front --lb-name cslb --name myHealthProbe --protocol tcp --port 80

# Create a load balancer rule
az network lb rule create --resource-group rg-cslb-front --lb-name cslb --name myHTTPRule --protocol tcp --frontend-port 80 --backend-port 80 --frontend-ip-name ip-front --backend-pool-name pool-back --probe-name myHealthProbe --disable-outbound-snat true --idle-timeout 15 --enable-tcp-reset true

# Set the subscription context to Azure Subscription B
az account set --name '<subscription B name>'

# Create and attach a network interface card to the load balancer
az network nic create --name nic-back --resource-group rg-cslb-back --vnet vnet-back --subnet back --lb-address-pool '/subscriptions/<subscription A ID>/resourceGroups/rg-cslb-front/providers/Microsoft.Network/loadBalancers/cslb/backendAddressPools/pool-back'

###########
### Clean up
###########

az group delete --name rg-cslb-back --no-wait --yes
az account set --name '<subscription B name>'
az group delete --name rg-cslb-front --no-wait --yes