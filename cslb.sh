export TENANT_ID="<your tenant ID>"
export SUB_A_NAME="<name of subscription A>"
export SUB_A_ID="<subscription ID of subscription A>"
export SUB_B_NAME="<name of subscription B>"
export SUB_B_ID="<subscription ID of subscription B>"
export LOCATION="centralus"
export RG_FRONT_NAME="<front end resource group name>"
export RG_BACK_NAME="<back end resource group name>"

# Sign in to Azure CLI
az login --tenant $TENANT_ID --use-device-code

###########
### Initial setup, subscription B
###########

# Change subscription to Azure Subscription B where the backend virtual network and load balancer pool will reside
az account set --name $SUB_B_NAME

# Create a resource group in Azure Subscription B 
az group create --name $RG_BACK_NAME --location $LOCATION

# Create a backend vnet in subscription B
az network vnet create -g $RG_BACK_NAME -n vnet-back --address-prefix 10.2.0.0/16 --subnet-name back --subnet-prefixes 10.2.0.0/24

###########
### Initial setup, subscription A
###########

# Change subscription to Azure Subscription A where the load balancer and front end will reside
az account set --name $SUB_A_NAME

# Create a resource group in Azure Subscription A 
az group create --name $RG_FRONT_NAME --location $LOCATION

###########
### Load balancer setup, subscription A
###########

# Create a load balancer with a frontend public IP address in subscription A
az network lb create --resource-group $RG_FRONT_NAME --name cslb --sku Standard --frontend-ip-name ip-front --tags 'IsRemoteFrontend=true'

# Create a back end pool in the vnet of Subscription B
az network lb address-pool create --address-pool-name pool-back --lb-name cslb --resource-group $RG_FRONT_NAME --vnet '/subscriptions/'$SUB_B_ID'/resourceGroups/'$RG_BACK_NAME'/providers/Microsoft.Network/virtualNetworks/vnet-back' --sync-mode Automatic

# Create a health probe
az network lb probe create --resource-group $RG_FRONT_NAME --lb-name cslb --name myHealthProbe --protocol tcp --port 80

# Create a load balancer rule
az network lb rule create --resource-group $RG_FRONT_NAME --lb-name cslb --name myHTTPRule --protocol tcp --frontend-port 80 --backend-port 80 --frontend-ip-name ip-front --backend-pool-name pool-back --probe-name myHealthProbe --disable-outbound-snat true --idle-timeout 15 --enable-tcp-reset true

# Set the subscription context to Azure Subscription B
az account set --name $SUB_B_NAME

# Attach the network interface card to the load balancer
az network nic create --name nic-back --resource-group $RG_BACK_NAME --vnet vnet-back --subnet back --lb-address-pool '/subscriptions/'$SUB_A_ID'/resourceGroups/'$RG_FRONT_NAME'/providers/Microsoft.Network/loadBalancers/cslb/backendAddressPools/pool-back'

###########
### Clean up
###########

az group delete --name $RG_BACK_NAME --no-wait --yes
az account set --name $SUB_A_NAME
az group delete --name $RG_FRONT_NAME --no-wait --yes