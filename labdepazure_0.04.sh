#!/bin/bash
#!/usr/bin/expect
#read -p "This script is to perform maintainance activities to your Azure Account. Press Y to continue you may need to sign in to your accoutnt. Or press any other key to Exit " c
c=y
if [ "$c" == "y" ]  || [ "$c" == 'Y' ]
then

#az login
loop=1
az account list | grep -A 5 -i cloudname  | grep "\"name\":" | cut -d "\"" -f 4 > /tmp/subslist.txt
az account list | grep -A 5 -i cloudname  | grep "\"id\":" | cut -d "\"" -f 4 > /tmp/subidlist.txt
declare rg_name
declare location
declare reqsub
declare sku
declare vnet
num=`echo $RANDOM`
tvm=1


rg_create()
{
#Function to create resource group name.
rg_name=`echo  "scenario"$1"_"$num`
az account list-locations -o json | grep "\"name\"" | cut -d ":" -f 2 | cut -d "\"" -f 2
echo " "
echo " " 
read -p "Enter location i.e. EastUS, WestUs, etc. from above list   " location


az group create --name $rg_name --location $location --subscription $reqsub 1> /dev/null
az group list -o table 
}
vnet_create()
{
if [ $2 ] 
then 
vap=$2
sap=$3
else
echo " "
echo " "
echo "Enter details for  Vnet and subnet"
echo " "
echo " "
read -p "Enter the prefix for Vnet, like 192.168.0.0/24 : - " vap
echo " "
echo " "
read -p "Enter the prefix for Subnet like 192.168.0.0/26 : - " sap
fi
#vnet=`echo  "vnet"$num`
az network vnet create --name $1 --resource-group $rg_name  --location $location --address-prefixes $vap --subnet-name subnet1 --subnet-prefixes $sap --subscription $reqsub 1> /dev/null
if [ "$1" == "hub" ] || [ "$1" == "ipsecnetwork" ]
then
if [ $4 ]
then
gap=$4
else
echo " "
echo " "
read -p "This Vnet need Gateway Enter the prefix for Gateway subnet like 192.168.0.0/26  " gap
echo " "
echo " "
fi
echo "Creating Gateway Subnet" 
az network vnet subnet create --name gatewaysubnet --resource-group $rg_name  --vnet-name $1  --address-prefixes $gap  --subscription $reqsub 1> /dev/null
fi
az network vnet list -o table --subscription $reqsub
}

subnet_create()
{
az network vnet subnet create --name $1 --resource-group $rg_name  --vnet-name $2 --address-prefixes $3 --subscription $reqsub 1> /dev/null
}

lb_create()
{
echo " "
echo " "
echo "Creating load balancer"
sku=$1
lbtyp=$2
#read -p "Enter the sku for LB basic or standard (lower case)" sku
#read -p "LB internal or external press i or e" lbtyp
lbname=`echo  "lb"$num`

if [ "$sku" == "basic" ]
then
    if [ "$lbtyp" == "i" ]
    then
    az network lb create --name $lbname --sku $sku --location $location --resource-group $rg_name --vnet-name $vnet --subnet subnet1 --public-ip-address "" --subscription $reqsub 1> /dev/null
    else
     pip_create lbip basic dynamic 
    az network lb create --name $lbname --sku $sku --location $location --resource-group $rg_name --public-ip-address pip-$num-lbip  --frontend-ip-name LoadBalancerFrontEnd --subscription $reqsub 1> /dev/null
    fi
else 
  if [ $lbtyp == "i" ]
   then
   az network lb create --name $lbname --sku $sku --location $location --resource-group $rg_name --vnet-name $vnet --subnet subnet1 --public-ip-address "" --subscription $reqsub 1> /dev/null
   else
   pip_create lbip standard static
   az network lb create --name $lbname --sku $sku --location $location --resource-group $rg_name --public-ip-address  pip-$num-lbip --frontend-ip-name LoadBalancerFrontEnd --subscription $reqsub 1> /dev/null
   fi
fi
az network lb list -o table 
}

nsg_create()
{
az network nsg create -g $rg_name --subscription $reqsub --name $1  --location $location 1> /dev/null
}

nsgrule_create()
{
az network nsg rule create --name vmacess --nsg-name $2  --priority 111 --resource-group $rg_name --subscription $reqsub --destination-address-prefixes '*' --source-address-prefixes '*' --protocol tcp --access allow --source-port-ranges '*' --destination-port-ranges $1 80 443 1> /dev/null
}
 
pip_create()
{
#create PIP with argumenst nameid, sku = basic or standard, allocation =  statis or dynamic
if [ "$1" == "name" ] 
then 
az network public-ip create --name $2 --sku $3 --location $location --subscription $reqsub --resource-group $rg_name --allocation-method $4 1> /dev/null
else
az network public-ip create --name pip-$num-$1 --sku $2 --location $location --subscription $reqsub --resource-group $rg_name --allocation-method $3 1> /dev/null
fi
}



vm_create_lb()
{
 
#read -p "Enter the image - CoreOS, Debian, SLES, RHEL, openSUSE-Leap, CentOS, UbuntuLTS, Win2012Datacenter, Win2012R2Datacenter, Win2019Datacenter, Win2016Datacenter:-  " image
image=$2
add_backend $image
img=`echo $image | cut -d "2" -f 1`

#calling function to add nsg rule for port based on OS
if  [ "$img" == "Win" ]
     then
     nsgrule_create 3389 nsg-$num
     else 
     nsgrule_create 22 nsg-$num
     fi
echo " "
echo " "
echo "Creating VMs"
echo " "
chksize=`az vm list-sizes -o tsv --location $location | awk '{print $3}' | grep Standard_DS1_v2`

if [ "$chksize" != "Standard_DS1_v2" ]
then
echo " "
az vm list-sizes -o table --location $location
echo " "
echo " "
echo "Program uses VM size as Standard_DS1_v2 selected location does not have this size available please choose a vm size from above"
read -p "Enter vmsize "chksize
fi
#echo "pasing $1 " $1 
if [ $1 != 1 ]
then

for((i=1;$i<=$1;i++))

do
add_natrule $i $img $lbname

 if  [ "$img" == "Win" ]
     then
      az network nic create --name nic-$num$i --lb-address-pools $mybackendpool --lb-inbound-nat-rules natrule$i --resource-group $rg_name --lb-name $lbname --vnet-name $vnet --subnet subnet1  --network-security-group nsg-$num --location $location --subscription $reqsub 1> /dev/null
     az vm create --name vm-$num$i --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $image --license-type none  --size $chksize  --nics  nic-$num$i  --subscription $reqsub 1> /dev/null
     else
     az network nic create --name nic-$num$i --lb-address-pools $mybackendpool --lb-inbound-nat-rules natrule$i --resource-group $rg_name --lb-name $lbname --vnet-name $vnet --subnet subnet1 --location $location --network-security-group nsg-$num --subscription $reqsub 1> /dev/null
     az vm create --name vm-$num$i --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $image  --size $chksize  --nics  nic-$num$i  --subscription $reqsub 1> /dev/null
     fi

done

else
if [ "$lbtyp" == "i" ]
then
echo " "
echo " "
echo " LB type choosen as Internal creating VM with public IP"

     if [ "$sku" == "basic" ]  
     then
     pip_create $1 basic dynamic
     az network nic create --name nic-$num$1 --lb-address-pools $mybackendpool --resource-group $rg_name --lb-name $lbname --vnet-name $vnet --subnet subnet1 --network-security-group nsg-$num --public-ip-address pip-$num-$1 --location $location --subscription $reqsub 1> /dev/null
        if  [ "$img" == "Win" ]
        then
         az vm create --name vm-$num$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $image  --license-type none --size $chksize  --nics  nic-$num$1  --subscription $reqsub --location $location 1> /dev/null
         else 
         az vm create --name vm-$num$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $image --size $chksize  --nics  nic-$num$1  --subscription $reqsub --location $location 1> /dev/null
         fi
    else
    pip_create $1 standard static
    az network nic create --name nic-$num$1 --lb-address-pools $mybackendpool --resource-group $rg_name --lb-name $lbname --vnet-name $vnet --subnet subnet1 --public-ip-address pip-$num-$1 --network-security-group nsg-$num --location $location --subscription $reqsub 1> /dev/null
    
           if [ "$img" == "Win" ]
           then
           az vm create --name vm-$num$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $image  --size $chksize  --nics  nic-$num$1  --subscription $reqsub --license-type none 1> /dev/null
            else 
           az vm create --name vm-$num$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $image  --size $chksize  --nics  nic-$num$1  --subscription $reqsub 1> /dev/null
         fi
     fi
#az vm create --name vm-$num$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $image --nsg nsg-$num --nsg-rule {RDP, SSH, HTTP, HTTPS} --license-type none --size $chksize  --nics  nic-$num$1  --subscription $reqsub

else
     if  [ "$img" == "Win" ]
     then
      az network nic create --name nic-$num$1 --lb-address-pools $mybackendpool --resource-group $rg_name --lb-name $lbname --vnet-name $vnet --subnet subnet1  --network-security-group nsg-$num --location $location --subscription $reqsub 1> /dev/null
     az vm create --name vm-$num$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $image --license-type none  --size $chksize  --nics  nic-$num$1  --subscription $reqsub 1> /dev/null 
     else
     az network nic create --name nic-$num$1 --lb-address-pools $mybackendpool --resource-group $rg_name --lb-name $lbname --vnet-name $vnet --subnet subnet1 --location $location --network-security-group nsg-$num --subscription $reqsub 1> /dev/null
     az vm create --name vm-$num$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $image  --size $chksize  --nics  nic-$num$1  --subscription $reqsub 1> /dev/null 
     fi


fi
fi
add_lbrule $img $mybackendpool
}

add_backend()
{
mybackendpool=`echo $lbname"bepool"`
echo " "
echo " "
echo "Creating backend Setting" 
#az network lb address-pool create -g $rg_name --subscription $reqsub --lb-name $lbname -n mybackendpool
img=`echo $1 | cut -d "2" -f 1`
if [ "$img" == "Win" ]
then 
az network lb probe create  -g $rg_name --subscription $reqsub --lb-name $lbname -n probe3389  --protocol tcp --port 3389 1> /dev/null
else 
az network lb probe create  -g $rg_name --subscription $reqsub --lb-name $lbname -n probe22 --protocol tcp --port 22 1> /dev/null
fi
}

add_lbrule()
{
echo " "
echo " "
echo "Adding backend rules"
if [ $tvm ==  1 ]
then
if [ "$1" == "Win" ]
then
az network lb rule create --name rule3389 --backend-port 3389 --frontend-port 3389 --subscription $reqsub --lb-name $lbname  --resource-group $rg_name --backend-pool-name $2 --frontend-ip-name  loadbalancerfrontend --protocol tcp --probe-name probe3389 1> /dev/null 
else 
az network lb rule create --name rule22 --backend-port 22 --frontend-port 22 --subscription $reqsub --lb-name $lbname  --resource-group $rg_name --backend-pool-name $2 --frontend-ip-name  loadbalancerfrontend --protocol tcp --probe-name probe22  1> /dev/null
fi
else
az network lb rule create --name rule22 --backend-port 80 --frontend-port 80 --subscription $reqsub --lb-name $lbname  --resource-group $rg_name --backend-pool-name $2 --frontend-ip-name  loadbalancerfrontend --protocol tcp --probe-name probe22  1> /dev/null
fi
}

add_natrule()
{
fep=$(( 10000 + $1))
if [ "$2" == "Win" ] 
   then 
az network lb inbound-nat-rule create --backend-port 3389 --frontend-port $fep --name natrule$1 --protocol tcp --frontend-ip-name LoadBalancerFrontEnd --resource-group $rg_name --subscription $reqsub --lb-name $3

else 
az network lb inbound-nat-rule create --backend-port 22 --frontend-port $fep --name natrule$1 --protocol tcp --frontend-ip-name LoadBalancerFrontEnd --resource-group $rg_name --subscription $reqsub --lb-name $3
fi
}

vmwpip_create()
{
#Function to create VMs with PIP pass in arguments as total no. of Vm, followed by Vnet name, port of OS, OSimagename
chksize=`az vm list-sizes -o tsv --location $location | awk '{print $3}' | grep Standard_DS1_v2`
if [ "$chksize" != "Standard_DS1_v2" ]
then
echo " "
az vm list-sizes -o table --location $location
echo " "
echo " "
echo "Program uses VM size as Standard_DS1_v2 selected location does not have this size available please choose a vm size from above"
read -p "Enter vmsize "chksize
fi

if [ $1 > 1 ]
then
args=("$@")
x=0
for((i=1;$i<=${args[0]};i++))
do
v=${args[$x+1]}
p=${args[$x+2]}
#p=${args[$x+3]}
img=`echo ${args[$x+3]} | cut -d "2" -f 1`
if [ $i == ${args[0]} ] 
then
echo " Creating VM " $i
nsg_create nsg-$num-$i
nsgrule_create $p  nsg-$num-$i
pip_create $i basic dynamic
az network nic create --name nic-$num$i --resource-group $rg_name --vnet-name $v --subnet subnet1 --public-ip-address pip-$num-$i --network-security-group nsg-$num-$i --location $location --subscription $reqsub 1> /dev/null
if  [ "$img" == "Win" ]
        then
         az vm create --name vm-$num-$i --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image ${args[$x+3]}  --license-type none --size $chksize  --nics  nic-$num$i  --subscription $reqsub --location $location 1> /dev/null
         else
         az vm create --name vm-$num-$i --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image ${args[$x+3]} --size $chksize  --nics  nic-$num$i  --subscription $reqsub --location $location 1> /dev/null
fi
else
echo " Creating VM " $i
nsg_create nsg-$num-$i
nsgrule_create $p  nsg-$num-$i
pip_create $i basic dynamic
az network nic create --name nic-$num$i --resource-group $rg_name --vnet-name $v --subnet subnet1 --public-ip-address pip-$num-$i --network-security-group nsg-$num-$i --location $location --subscription $reqsub 1> /dev/null
if  [ "$img" == "Win" ]
        then
         az vm create --name vm-$num-$i --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image ${args[$x+3]}  --license-type none --size $chksize  --nics  nic-$num$i  --subscription $reqsub --location $location 1> /dev/null&
         else
         az vm create --name vm-$num-$i --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image ${args[$x+3]} --size $chksize  --nics  nic-$num$i  --subscription $reqsub --location $location 1> /dev/null&
fi
fi
x=$(( $x + 3 ))
done
else
nsg_create nsg-$num-$1
nsgrule_create $3  nsg-$num-$1
pip_create $1 basic dynamic
az network nic create --name nic-$num$1 --resource-group $rg_name --vnet-name $2 --subnet subnet1 --public-ip-address pip-$num-$1 --network-security-group nsg-$num-$1 --location $location --subscription $reqsub 1> /dev/null
#if [ "$chksize" != "Standard_DS1_v2" ]
#then
#echo " "
#az vm list-sizes -o table --location $location
#echo " "
#echo " "
#echo "Program uses VM size as Standard_DS1_v2 selected location does not have this size available please choose a vm size from above"
#read -p "Enter vmsize "chksize
#fi
img=`echo $4 | cut -d "2" -f 1`
if  [ "$img" == "Win" ]
        then
         az vm create --name vm-$num-$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $4  --license-type none --size $chksize  --nics  nic-$num$1  --subscription $reqsub --location $location 1> /dev/null
         else
         az vm create --name vm-$num-$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $4 --size $chksize  --nics  nic-$num$1  --subscription $reqsub --location $location 1> /dev/null
fi
fi
}
vmdip_create()
{
nsg_create nsg-$num-$1
nsgrule_create $3  nsg-$num-$1
az network nic create --name nic-$num$1 --resource-group $rg_name --vnet-name $2 --subnet subnet1 --network-security-group nsg-$num-$1 --location $location --subscription $reqsub 1> /dev/null
chksize=`az vm list-sizes -o tsv --location $location | awk '{print $3}' | grep Standard_DS1_v2`
if [ "$chksize" != "Standard_DS1_v2" ]
then
echo " "
az vm list-sizes -o table --location $location
echo " "
echo " "
echo "Program uses VM size as Standard_DS1_v2 selected location does not have this size available please choose a vm size from above"
read -p "Enter vmsize "chksize
fi
img=`echo $4 | cut -d "2" -f 1`
if  [ "$img" == "Win" ]
        then
         az vm create --name vm-$num$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $4  --license-type none --size $chksize  --nics  nic-$num$1  --subscription $reqsub --location $location 1> /dev/null
         else
         az vm create --name vm-$num$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $4 --size $chksize  --nics  nic-$num$1  --subscription $reqsub --location $location 1> /dev/null
fi
}


peer_create()
{

echo " "
echo " "
echo " Creating peering" 
echo " "
echo " "
if [ $3 ]
then
    if [ $4 ] 
      then 
          if [ $5 ]
             then 
             az network vnet peering create  --resource-group $rg_name  -n $1to$2 --vnet-name $1 --remote-vnet $2 --$3 --$4 --$5  --subscription $reqsub 1> /dev/null
           else 
             az network vnet peering create  --resource-group $rg_name  -n $1to$2 --vnet-name $1 --remote-vnet $2 --$3 --$4 --subscription $reqsub 1> /dev/null
           fi
     else 
      az network vnet peering create  --resource-group $rg_name  -n $1to$2 --vnet-name $1 --remote-vnet $2 --$3 --subscription $reqsub 1> /dev/null
    fi
else
az network vnet peering create  --resource-group $rg_name  -n $1to$2 --vnet-name $1 --remote-vnet $2   --subscription $reqsub 1> /dev/null
fi

}

vpngateway_create()
{
echo " "
echo " "
echo " Creating VPN gateways" 
args=("$@")
for((i=1;$i<=${args[0]};i++))
do
pip_create ${args[$i]} basic dynamic
if [ $i == ${args[0]} ]
then
az network vnet-gateway create --name vpngw-${args[$i]} --subscription $reqsub --resource-group $rg_name --vpn-type routebased --public-ip-addresses pip-$num-${args[$i]} --sku VpnGw1 --gateway-type vpn --vnet ${args[$i]} 1> /dev/null
else
az network vnet-gateway create --name vpngw-${args[$i]} --subscription $reqsub --resource-group $rg_name --vpn-type routebased --public-ip-addresses pip-$num-${args[$i]} --sku VpnGw1 --gateway-type vpn --vnet ${args[$i]} 1> /dev/null&
sleep 10
fi
done
#if [ $2 ]
#then
#echo " "
#echo " "
#echo "Creating VPN gateways" 
#pip_create $1 basic dynamic
#pip_create $2 basic dynamic
#echo " "
#echo " "
#az network vnet-gateway create --name vpngw-$1 --subscription $reqsub --resource-group $rg_name --vpn-type routebased --public-ip-addresses pip-$num-$1 --sku VpnGw1 --gateway-type vpn --vnet $1 1> /dev/null&
#sleep 10
#az network vnet-gateway create --name vpngw-$2 --subscription $reqsub --resource-group $rg_name --vpn-type routebased --public-ip-addresses pip-$num-$2 --sku VpnGw1 --gateway-type vpn --vnet $2 1> /dev/null
#else 
#pip_create $1 basic dynamic
#echo " "
#echo " "
#echo "Creating VPN gateway for " $1
#az network vnet-gateway create --name vpngw-$1 --subscription $reqsub --resource-group $rg_name --vpn-type routebased --public-ip-addresses pip-$num-$1 --sku VpnGw1 --gateway-type vpn --vnet $1 1> /dev/null
#fi
}

localgateway_create()
{
echo " "
echo " "
echo "Creating local network gateway for " $1 " to " $2 
if [ $5 ]
then
az network local-gateway create --name localgateway$1 --gateway-ip-address $3  --resource-group $rg_name --subscription $reqsub --local-address-prefixes $4 $5 1> /dev/null
else
az network local-gateway create --name localgateway$1 --gateway-ip-address $3  --resource-group $rg_name --subscription $reqsub --local-address-prefixes $4 1> /dev/null
fi

}

ipsecconection_create()
{
#Function to create IPSEC connection between VPN GW and Localgateway pass on arguments vpngwname and localwgname
echo " "
echo " "
echo "Creating connection for " $1 " to " $2
az network vpn-connection create --name ipsec-connection-$1-$2 --vnet-gateway1 $1 --local-gateway2 $2 --shared-key abc123 --location $location --resource-group $rg_name --subscription $reqsub 1> /dev/null
}

subnet_add()
{
#function to create subnet in Vnet, pass arguments as Vnetname, Subnetname and address space
echo " "
echo " "
echo "Adding Subnet " $2 " in Vnet" $1

az network vnet subnet create --resource-group $rg_name --subscription $reqsub --vnet-name $1 --name $2 --address-prefixes $3 1> /dev/null
}

appgateway_create()
{
#Function to add application gateway, take arguments as sku, front end port, http settings, backend server
if [ $2 == 80 ]
then
az network application-gateway create --resource-group $rg_name --subscription $reqsub  --sku  $1 --frontend-port $2 --http-settings-protocol http --location $location --public-ip-address appgwip --routing-rule-type $3 --servers $4 --subnet appgwsubnet --vnet-name appgwvnet --name appggwtest 1> /dev/null

else
echo " "
echo " " 
   if [ "$5" == e2e ]
then
az network application-gateway create --resource-group $rg_name --subscription $reqsub  --sku  $1 --frontend-port $2 --http-settings-protocol https --http-settings-port 443 --location $location --public-ip-address appgwip --routing-rule-type $3 --servers $4 --subnet appgwsubnet --vnet-name appgwvnet --name appggwtest --cert-file ./tmpcert/listener.pfx --cert-password abc123  1> /dev/null
sleep 1
az network application-gateway auth-cert create --cert-file ./tmpcert/nginx.cer --gateway-name appggwtest --name authcernginx --resource-group $rg_name --subscription $reqsub 1> /dev/null
sleep 1
az network application-gateway http-settings update --resource-group $rg_name --subscription $reqsub  --gateway-name appggwtest --name appGatewayBackendHttpSettings --auth-certs authcernginx 1> /dev/null
else
#calling function to create certificates
create_cert 
az network application-gateway create --resource-group $rg_name --subscription $reqsub  --sku  $1 --frontend-port $2 --http-settings-protocol http --location $location --public-ip-address appgwip --routing-rule-type $3 --servers $4 --subnet appgwsubnet --vnet-name appgwvnet --name appggwtest --cert-file ./tmpcert/listener.pfx --cert-password abc123  1> /dev/null
    fi

fi
}

appgatewayv2_create()
{
pip_create name appgwip standard static
if [ $2 == 80 ]
then
az network application-gateway create --resource-group $rg_name --subscription $reqsub  --sku  $1 --frontend-port $2 --http-settings-protocol http --location $location --public-ip-address appgwip --routing-rule-type $3 --servers $4 --subnet appgwsubnet --vnet-name appgwvnet --name appggwtest 1> /dev/null

else

if [ "$5" == e2e ]
then
az network application-gateway create --resource-group $rg_name --subscription $reqsub  --sku  $1 --frontend-port $2 --http-settings-protocol https --http-settings-port 443 --location $location --public-ip-address appgwip --routing-rule-type $3 --servers $4 --subnet appgwsubnet --vnet-name appgwvnet --name appggwtest --cert-file ./tmpcert/listener.pfx --cert-password abc123  1> /dev/null
sleep 1
az network application-gateway root-cert create --gateway-name appggwtest --name berootcert --resource-group $rg_name --subscription $reqsub --cert-file ./tmpcert/beroot.cer 
else
#calling function to create certificates
create_cert
az network application-gateway create --resource-group $rg_name --subscription $reqsub  --sku  $1 --frontend-port $2 --http-settings-protocol http --location $location --public-ip-address appgwip --routing-rule-type $3 --servers $4 --subnet appgwsubnet --vnet-name appgwvnet --name appggwtest --cert-file ./tmpcert/listener.pfx --cert-password abc123  1> /dev/null
    fi
fi
}

create_cert()
{
if [ ! -f /usr/bin/openssl ]
then
echo "Does not look like you have openssl installed on this PC, This scenario need openssl to be installed"
read -p "Press c and enter to continue script will install openssl or press any key to exit" choice
        if [ "$choice" == "c" ] || [ "$choice" == "C" ] 
         then 
         echo " Installing OpenSSL" 
         read -p "Enter 1 to use yum if your OS / shell is centos based, enter 2 if your os/ shell is ubuntu or debian based " os
             case "$os" in
             "1")
                yum install openssl -y 1> /dev/null
             ;;
             "2")   
              apt-get install openssl -y 1> /dev/null
             ;;
             "")  
               echo "incorrect entry exiting"
               echo "Clearing already created resources" 
               az group delete --name $rg_name --location $location --subscription $reqsub 1> /dev/null
               exit 
          esac
       else
           echo "Exiting program and clearing already created resources"
             az group delete --name $rg_name --location $location --subscription $reqsub 1> /dev/null
         exit 
         fi 
        sleep 1
    #check again for openssl
    osslchk=`ls  /usr/bin/openssl`
    if [ ! -f /usr/bin/openssl ]
    then
    echo "Openssl install didnt work, exiting try again after installing openssl manually" 
    echo "Exiting program and clearing already created resources"
             az group delete --name $rg_name --location $location --subscription $reqsub 1> /dev/null
    exit  
  fi
fi
mkdir tmpcert
cd ./tmpcert
openssl req -nodes -newkey rsa:2048 -keyout listener.key -out listener.csr -subj "/C=ro/ST=xx/L=xx/O=Gl/OU=IT/CN=c"
openssl req -x509 -sha256 -days 365 -key listener.key -in listener.csr -out listener.pem
openssl pkcs12 -export -out listener.pfx -inkey listener.key -in listener.pem -passout pass:abc123
if [ "$1" == "e2e" ]
then 
if [ "$2" == "v2" ]
then
#openssl req -nodes -newkey rsa:2048 -keyout beroot.key -out beroot.csr -subj "/C=ro/ST=xx/L=xx/O=Gl/OU=IT/CN=c"
#openssl req -x509 -sha256 -days 365 -key beroot.key -in beroot.csr -out beroot.pem
#openssl pkcs12 -export -out beroot.pfx  -inkey beroot.key -in beroot.pem -passout pass:abc123
#openssl pkcs12 -in beroot.pfx -out beroot.cer -nodes -passin  pass:abc123
#openssl req -nodes -newkey rsa:2048 -keyout nginx.key -out nginx.csr -subj "/C=ng/ST=xx/L=xx/O=Gl/OU=IT/CN=c"
#openssl x509 -req -in nginx.csr -CA ./beroot.pem -CAkey ./beroot.key -CAcreateserial -out nginx.crt -days 500 -sha256
echo " "
echo " "
echo "Creating Certificates for V2 app gateway need manual inputs in E2E SSL"
echo " "
echo " "
echo " "
echo "Creating root key"
echo " "
echo " "
openssl genrsa -des3 -out beroot.key 1024
echo "Creating root cert"
echo " "
echo " "
openssl req -new -x509 -key beroot.key -out beroot.cer -days 3600
echo " "
echo " "
echo " Creating backend key" 
echo " "
echo " "
#openssl genrsa -des3 -out nginx.key 1024
echo " "
echo " "
echo "Creating backend cert request"
echo " "
echo " "
openssl req -nodes -newkey rsa:2048 -keyout nginx.key -out nginx.csr -subj "/C=ng/ST=xx/L=xx/O=Gl/OU=IT/CN=$3"
#openssl req -new -key nginx.key -out nginx.csr -subj "/C=ng/ST=xx/L=xx/O=Gl/OU=IT/CN=$3"
echo " "
echo " "
echo "Creating backend certificate"
echo " "
echo " "
openssl x509 -req -days 360 -in nginx.csr -CA beroot.cer -CAkey beroot.key -CAcreateserial -out nginx.crt
else 
openssl req -nodes -newkey rsa:2048 -keyout nginx.key -out nginx.csr -subj "/C=ng/ST=xx/L=xx/O=Gl/OU=IT/CN=c"
openssl req -x509 -sha256 -days 365 -key nginx.key -in nginx.csr -out nginx.pem
openssl pkcs12 -export -out nginx.pfx  -inkey nginx.key -in nginx.pem -passout pass:abc123
openssl pkcs12 -in nginx.pfx -out nginx.cer -nodes -passin  pass:abc123
openssl x509 -inform pem  -in nginx.cer -out nginx.crt
fi
fi
cd ../
}

prepare_e2evm()
{
#function to create HTTPS settings in backend VM
echo "server {" > default
echo "  listen 80 default_server;" >> default
echo "        listen [::]:80 default_server;" >> default
echo "        listen 443 ssl;" >> default
echo " root /var/www/html;" >> default
echo " index index.html index.htm index.nginx-debian.html;" >> default
echo " " >> default 
echo "        server_name " $3";" >> default
echo "        ssl_certificate /etc/nginx/nginx.crt;" >> default
echo "        ssl_certificate_key /etc/nginx/nginx.key;" >> default
echo "        server_name _;" >> default
echo " " >> default
echo "        location / {" >> default
echo "   try_files \$uri \$uri/ =404;" >> default
echo "        }" >> default
echo "}" >> default
curl --insecure --user labuser:p@ssw0rd12345 -T ./default sftp://$2/home/labuser/ 1> /dev/null
curl --insecure --user labuser:p@ssw0rd12345 -T ./tmpcert/nginx.crt sftp://$2/home/labuser/ 1> /dev/null
curl --insecure --user labuser:p@ssw0rd12345 -T ./tmpcert/nginx.key sftp://$2/home/labuser/ 1> /dev/null
az vm run-command invoke --subscription $reqsub --resource-group $rg_name  --name $1 --command-id RunShellScript --scripts 'sudo apt-get install nginx -y;sudo sleep 1; sudo cp /home/labuser/default /etc/nginx/sites-available/default; sudo cp /home/labuser/nginx* /etc/nginx/ ; sudo /etc/init.d/nginx restart'& 1> /dev/null
rm ./default
}

acr_create()
{
az acr create --resource-group $rg_name --subscription $reqsub  --name acrtest$num --sku Basic
echo " "
echo " " 
echo " ACR created login in to ACR"
az acr login --name acrtest$num
echo " "
echo " "
echo "Tagging Docker image to ACR"
acrloginserver=`az acr list --resource-group $rg_name   --subscription $reqsub --query "[].{acrLoginServer:loginServer}" --output table | grep acrtest$num`
docker tag azure-vote-front $acrloginserver/azure-vote-front:v1
echo " "
echo " "
echo "Pushing DockerImage to ACR"
docker push $acrloginserver/azure-vote-front:v1
}

aks_create()
{
echo " "
echo " "
echo "Adding AKS cluster"
az aks create --resource-group $rg_name  --subscription $reqsub --name myAKScluster --node-count 2 --service-principal $1 --client-secret $2 --generate-ssh-keys
sleep 20
az aks get-credentials --resource-group $rg_name --subscription $reqsub  --name myAKSCluster
}


sp_create()
{
echo " " 
echo " " 
echo "Adding new service principal for deployment"
az ad sp create-for-rbac --skip-assignment > ./details.txt
appid=`cat ./details.txt | grep appId | cut -d ":" -f 2 | cut -d "\"" -f 2`
password=`grep password details.txt | cut -d ":" -f 2 | cut -d "\"" -f 2`
scopeid=`az acr show --subscription $reqsub --resource-group $rg_name --name acrtest$num --query "id" --output tsv`
echo " "
echo " "
echo "Performing role assignment"
sleep 100
az role assignment create --assignee $appid --scope $scopeid --role acrpull
aks_create $appid $password
rm ./details.txt
}


config_aks()
{
echo " "
echo " "
echo "Configuring AKS"
acrloginserver=`az acr list --resource-group $rg_name   --subscription $reqsub --query "[].{acrLoginServer:loginServer}" --output table | grep acrtest$num`
mv azure-vote-all-in-one-redis.yaml azure-vote-all-in-one-redis.yaml.bak
rm azure-vote-all-in-one-redis.yaml
echo "apiVersion: apps/v1beta1" >> azure-vote-all-in-one-redis.yaml
echo "kind: Deployment" >> azure-vote-all-in-one-redis.yaml
echo "metadata:" >> azure-vote-all-in-one-redis.yaml
echo "  name: azure-vote-back" >> azure-vote-all-in-one-redis.yaml
echo "spec:" >> azure-vote-all-in-one-redis.yaml
echo "  replicas: 1" >> azure-vote-all-in-one-redis.yaml
echo "  template:" >> azure-vote-all-in-one-redis.yaml
echo "    metadata:" >> azure-vote-all-in-one-redis.yaml
echo "      labels:" >> azure-vote-all-in-one-redis.yaml
echo "        app: azure-vote-back" >> azure-vote-all-in-one-redis.yaml
echo "    spec:" >> azure-vote-all-in-one-redis.yaml
echo "      nodeSelector:" >> azure-vote-all-in-one-redis.yaml
echo "        \"beta.kubernetes.io/os\": linux" >> azure-vote-all-in-one-redis.yaml
echo "      containers:" >> azure-vote-all-in-one-redis.yaml
echo "      - name: azure-vote-back" >> azure-vote-all-in-one-redis.yaml
echo "        image: redis" >> azure-vote-all-in-one-redis.yaml
echo "        ports:" >> azure-vote-all-in-one-redis.yaml
echo "        - containerPort: 6379" >> azure-vote-all-in-one-redis.yaml
echo "          name: redis" >> azure-vote-all-in-one-redis.yaml
echo "---" >> azure-vote-all-in-one-redis.yaml
echo "apiVersion: v1" >> azure-vote-all-in-one-redis.yaml
echo "kind: Service" >> azure-vote-all-in-one-redis.yaml
echo "metadata:" >> azure-vote-all-in-one-redis.yaml
echo "  name: azure-vote-back" >> azure-vote-all-in-one-redis.yaml
echo "spec:" >> azure-vote-all-in-one-redis.yaml
echo "  ports:" >> azure-vote-all-in-one-redis.yaml
echo "  - port: 6379" >> azure-vote-all-in-one-redis.yaml
echo "  selector:" >> azure-vote-all-in-one-redis.yaml
echo "    app: azure-vote-back" >> azure-vote-all-in-one-redis.yaml
echo "---" >> azure-vote-all-in-one-redis.yaml
echo "apiVersion: apps/v1beta1" >> azure-vote-all-in-one-redis.yaml
echo "kind: Deployment" >> azure-vote-all-in-one-redis.yaml
echo "metadata:" >> azure-vote-all-in-one-redis.yaml
echo "  name: azure-vote-front" >> azure-vote-all-in-one-redis.yaml
echo "spec:" >> azure-vote-all-in-one-redis.yaml
echo "  replicas: 1" >> azure-vote-all-in-one-redis.yaml
echo "  strategy:" >> azure-vote-all-in-one-redis.yaml
echo "    rollingUpdate:" >> azure-vote-all-in-one-redis.yaml
echo "      maxSurge: 1" >> azure-vote-all-in-one-redis.yaml
echo "      maxUnavailable: 1" >> azure-vote-all-in-one-redis.yaml
echo "  minReadySeconds: 5 " >> azure-vote-all-in-one-redis.yaml
echo "  template:" >> azure-vote-all-in-one-redis.yaml
echo "    metadata:" >> azure-vote-all-in-one-redis.yaml
echo "      labels:" >> azure-vote-all-in-one-redis.yaml
echo "        app: azure-vote-front" >> azure-vote-all-in-one-redis.yaml
echo "    spec:" >> azure-vote-all-in-one-redis.yaml
echo "      nodeSelector:" >> azure-vote-all-in-one-redis.yaml
echo "        \"beta.kubernetes.io/os\": linux" >> azure-vote-all-in-one-redis.yaml
echo "      containers:" >> azure-vote-all-in-one-redis.yaml
echo "      - name: azure-vote-front" >> azure-vote-all-in-one-redis.yaml
echo "        image: " $acrloginserver"/azure-vote-front:v1" >> azure-vote-all-in-one-redis.yaml
echo "        ports:" >> azure-vote-all-in-one-redis.yaml
echo "        - containerPort: 80" >> azure-vote-all-in-one-redis.yaml
echo "        resources:" >> azure-vote-all-in-one-redis.yaml
echo "          requests:" >> azure-vote-all-in-one-redis.yaml
echo "            cpu: 250m" >> azure-vote-all-in-one-redis.yaml
echo "          limits:" >> azure-vote-all-in-one-redis.yaml
echo "            cpu: 500m" >> azure-vote-all-in-one-redis.yaml
echo "        env:" >> azure-vote-all-in-one-redis.yaml
echo "        - name: REDIS" >> azure-vote-all-in-one-redis.yaml
echo "          value: "azure-vote-back"" >> azure-vote-all-in-one-redis.yaml
echo "---" >> azure-vote-all-in-one-redis.yaml
echo "apiVersion: v1" >> azure-vote-all-in-one-redis.yaml
echo "kind: Service" >> azure-vote-all-in-one-redis.yaml
echo "metadata:" >> azure-vote-all-in-one-redis.yaml
echo "  name: azure-vote-front" >> azure-vote-all-in-one-redis.yaml
echo "spec:" >> azure-vote-all-in-one-redis.yaml
echo "  type: LoadBalancer" >> azure-vote-all-in-one-redis.yaml
echo "  ports:" >> azure-vote-all-in-one-redis.yaml
echo "  - port: 80" >> azure-vote-all-in-one-redis.yaml
echo "  selector:" >> azure-vote-all-in-one-redis.yaml
echo "    app: azure-vote-front" >> azure-vote-all-in-one-redis.yaml
sleep 1
echo " "
echo " "
echo "Creating kubectl"
kubectl apply -f azure-vote-all-in-one-redis.yaml
echo "Giving wait time for 90s for kube to come up"
sleep 90
}

docker_runcheck()
{
status=`systemctl status docker.service | grep -i active | awk {'print $2'}`
if [ "$status" == "inactive" ]
then 
 echo " "
 echo " "
 echo -e "\e[ Docker service not running starting Docker"
 systemctl start docker.service
 sleep 2
 status=`systemctl status docker.service | grep -i active | awk {'print $2'}`
 if [ "$status" == "inactive" ]
 then 
 echo " "
 echo " "
 echo -e "\e[Docker Service start failed, start doceker service manually and retry. Exiting"
 exit
fi
fi
} 

aks_precheck()
{
echo " "
echo " "
echo -e "\e[1;38m  Performing prechecks for Git and Dockers binaries before install"
if [ -f /usr/bin/git ] && [ -f /usr/bin/docker ]
then 
echo " "
echo " "
echo -e "\e[1;38m  GIT and Docker apps are installed proceeding further"
docker_runcheck

else 
 echo " "
 echo " "
 echo -e "\e[1;38m  Required binaries for GIT AND/OR Dockers is missing, would required to be installed "
 echo -e "\e[1;38m  Please suggest linux base your are using, enter  1 for CentOS / RHEL base and 2 for Ubuntu / Debian based"
 read -p "   " los
   if [ ! -f /usr/bin/git ]
     then 
     echo " "
     echo " "
     echo -e "\e[1;38m GIT missing installing git"
       if [ $los -eq 1 ]
         then 
          sudo yum install git -y
       else 
       apt-get update 
       apt-get install git -y 
       fi
   fi
   if [ ! -f /usr/bin/docker ]
   then
     echo " "
     echo " "
     echo -e "\e[1;38m Docker missing installing Docker"
       if [ $los -eq 1 ]
         then
          sudo yum install docker -y
       else
       apt-get update
       apt-get install docker -y
       fi
    fi
   if [ ! -f /usr/bin/git ] ||  [ ! -f /usr/bin/docker ]
   then
  echo " "
  echo " "
  echo -e "\e[1;38m Still Could not load binaries of git and dockers, try to install them manually first, Exiting"
  exit
  else 
  docker_runcheck
  echo " "
  echo " "
  echo -e "\e[1;38m Git and Dockers are available now proceeding further" 
  fi
fi
}
 
     



#while [ $loop == 1 ]
#do:se
clear
totalsub=`cat /tmp/subslist.txt | wc -l`
#create_rgnameecho "Total Subs" $totalsub
echo " "
echo " "
echo " "
echo " "
echo -e "\e[1;38m===========Subscriptions in your account======================="
cat -n /tmp/subslist.txt
echo
echo

read -p "Enter the number of subscription you want to create resource in or q to exit " snum
if [ "$snum" == "q" ] || [ "$snum" == "Q" ]
then
loop=0
#rm /tmp/subslist.txt
#rm /tmp/subidlist.txt
exit
fi
if [ $snum -lt  1 ] || [ $snum -gt $totalsub ]
then
read -p  "Invalid entry please enter any key to proceed" p
else
reqsub=`head -n $snum /tmp/subidlist.txt | tail -n 1`
clear
echo -e "\e[1;38m  1.) Create ILB basic with single VM backend"
echo -e "\e[1;38m  2.) Create Ext. LB basic with single VM backend"
echo -e "\e[1;38m  3.) Standard ILB with single VM backend"
echo -e "\e[1;38m  4.) Stabdard Ext. LB with single VM in backend"
echo -e "\e[1;38m  5.) Standard Ext. LB with multiple VM in backend"
echo -e "\e[1;38m  6.) Peered Vnets and single windows VM with PIP in each Vnet"
echo -e "\e[1;38m  7.) Hub spoke model along with IPSEC connected Vnet with hub"
echo -e "\e[1;38m  8.) Application gateway  with HTTP listener and HTTP backend - Basic Rule"
echo -e "\e[1;38m  9.) Application gateway  with HTTPS listener and HTTP backend - Basic Rule"
echo -e "\e[1;38m 10.) Application gateway  with HTTPS listener with end to end SSL- Basic Rule"
echo -e "\e[1;38m 11.) Application gateway  WAF with HTTPS listener and HTTP backend - Basic Rule"
echo -e "\e[1;38m 12.) Application gateway  WAF with HTTPS listener and end to end ssl - Basic Rule"
echo -e "\e[1;38m 13.) Deploy AKS cluster with sample code in pods"
echo "  "
echo "  "
echo "  "
read -p " Enter scenario number " choice

#To take input for version of app gateway
if [ $choice -ge 8 ] && [ $choice -le 12 ]
then
read -p " Please enter version of app gateway you would like to use? Enter 1 for version 1 and 2 for version 2 " appgwver
#Loop to check incorrect input
while [ $appgwver -lt 1 ] || [ $appgwver -gt 2 ]
do
echo "Incorrect input" 
read -p " Please enter version of app gateway you would like to use?  Enter 1 for version 1 and 2 for version 2 " appgwver
done
fi

case "$choice" in

"1")
echo " "
echo " "
vnet=`echo  "vnet"$num`
rg_create $choice
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode vnet will be created using address space 192.168.101.0/24, overlapped addreses may cause issues or failure"
read -p "Enter S for silent mode" mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create $vnet  192.168.101.0/24 192.168.101.0/26
else
vnet_create $vnet
fi
echo " "
echo " "
read -p "Enter the image - CoreOS, Debian, SLES, RHEL, openSUSE-Leap, CentOS, UbuntuLTS, Win2012Datacenter, Win2012R2Datacenter, Win2019Datacenter, Win2016Datacenter:-  " image
lb_create basic i
nsg_create nsg-$num
vm_create_lb $tvm $image
;;
"2")
echo " "
echo " "
vnet=`echo  "vnet"$num`
rg_create $choice
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode vnet will be created using address space 192.168.102.0/24, overlapped addreses may cause issues or failure"
read -p "Enter S for silent mode "  mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create $vnet  192.168.102.0/24 192.168.102.0/26
else
vnet_create $vnet
fi
echo " "
echo " "
read -p "Enter the image - CoreOS, Debian, SLES, RHEL, openSUSE-Leap, CentOS, UbuntuLTS, Win2012Datacenter, Win2012R2Datacenter, Win2019Datacenter, Win2016Datacenter:-  " image
lb_create basic e
nsg_create nsg-$num
vm_create_lb $tvm $image
;;
"3")
echo " "
echo " "
vnet=`echo  "vnet"$num`
rg_create $choice
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode vnet will be created using address space 192.168.103.0/24, overlapped addreses may cause issues or failure"
read -p "Enter S for silent mode " mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create $vnet  192.168.103.0/24 192.168.103.0/26
else
vnet_create $vnet
fi
echo " "
echo " "
read -p "Enter the image - CoreOS, Debian, SLES, RHEL, openSUSE-Leap, CentOS, UbuntuLTS, Win2012Datacenter, Win2012R2Datacenter, Win2019Datacenter, Win2016Datacenter:-  " image
lb_create standard i
nsg_create nsg-$num
vm_create_lb $tvm $image
;;
"4")
echo " "
echo " "
vnet=`echo  "vnet"$num`
rg_create $choice
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode vnet will be created using address space 192.168.104.0/24, overlapped addreses may cause issues or failure"
read -p "Enter S for silent mode " mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create $vnet  192.168.104.0/24 192.168.104.0/26
else
vnet_create $vnet
fi
echo " "
echo " "
read -p "Enter the image - CoreOS, Debian, SLES, RHEL, openSUSE-Leap, CentOS, UbuntuLTS, Win2012Datacenter, Win2012R2Datacenter, Win2019Datacenter, Win2016Datacenter:-  " image
lb_create standard e
nsg_create nsg-$num
vm_create_lb $tvm $image
;;
"5")
echo " " 
echo " "
read -p "Enter number of VMs you want in backend   : " tvm
vnet=`echo  "vnet"$num`
rg_create $choice
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode vnet will be created using address space 192.168.105.0/24, overlapped addreses may cause issues or failure"
read -p "Enter S for silent mode " mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create $vnet  192.168.105.0/24 192.168.105.0/26
else
vnet_create $vnet
fi
echo " "
echo " "
read -p "Enter the image - CoreOS, Debian, SLES, RHEL, openSUSE-Leap, CentOS, UbuntuLTS, Win2012Datacenter, Win2012R2Datacenter, Win2019Datacenter, Win2016Datacenter:-  " image
lb_create standard e
nsg_create nsg-$num
vm_create_lb $tvm $image
;;
"6")
echo " "
echo " "
rg_create $choice
vnet=`echo  "vnet"$num`
vnet2=`echo  "vnet"$num"-2"`
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode vnet will be created using address space 192.168.106.0/24 and 192.168.107.0/24, overlapped addreses may cause issues or failure"
read -p "Enter S for silent mode " mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create $vnet  192.168.106.0/24 192.168.106.0/26
vnet_create $vnet2 192.168.107.0/24 192.168.107.0/26
else 
echo "Creating First Vnet"
vnet_create $vnet
echo "Creating seocnd Vnet"
vnet_create $vnet2
fi
echo " " 
echo " " 
echo "Creating VMs in both Vnets"
vmwpip_create 2 $vnet 3389 Win2016Datacenter $vnet2 3389 Win2016Datacenter
#vmwpip_create 2 $vnet2 3389 Win2016Datacenter
echo " " 
echo " " 
echo "Adding Vnet peering"
peer_create $vnet $vnet2 allow-vnet-access
peer_create $vnet2 $vnet allow-vnet-access
;;
"7")
echo " " 
echo " "
echo " "
echo " "
rg_create $choice
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode network for hub, spoke and ipsec would be 192.168.111.0/24, 192.168.112.0/24 192.168.113.0/24 respectively overlapped addreses may cause issues or failure"
read -p "Press S or s then enter for silent mode  " mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create hub 192.168.111.0/24 192.168.111.0/26 192.168.111.64/26
vnet_create spoke 192.168.112.0/24 192.168.112.0/26
vnet_create ipsecnetwork 192.168.113.0/24 192.168.113.0/26 192.168.113.64/26
else
echo " Creating HUB network"
vnet_create hub
echo " "
echo " "
echo " Creating spoke network"
vnet_create spoke
echo " "
echo " "
echo " Creating ipsec connected  network"
vnet_create ipsecnetwork
fi
vpngateway_create 2 hub ipsecnetwork
#vpngateway_create ipsecnetwork
lnip1=`az network public-ip show --name pip-$num-ipsecnetwork --subscription $reqsub --resource-group $rg_name |grep ipAddress | cut -d "\"" -f 4`
lnip2=`az network public-ip show --name pip-$num-hub --subscription $reqsub --resource-group $rg_name |grep ipAddress | cut -d "\"" -f 4`
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
netprefix1="192.168.113.0/24"
netprefix2="192.168.111.0/24"
netprefix3="192.168.112.0/24"
else
netprefix1=`az network vnet list --subscription $reqsub --resource-group $rg_name -o table | grep ipsecnetwork| awk '{print $5}'`
netprefix2=`az network vnet list --subscription $reqsub --resource-group $rg_name -o table | grep hub | awk '{print $5}'`
netprefix3=`az network vnet list --subscription $reqsub --resource-group $rg_name -o table | grep spoke | awk '{print $5}'`
fi
localgateway_create hub ipsecnetwork $lnip1 $netprefix1
localgateway_create ipsecnetwork hub $lnip2 $netprefix2 $netprefix3 
ipsecconection_create vpngw-hub localgatewayhub
ipsecconection_create vpngw-ipsecnetwork localgatewayipsecnetwork
echo " "
echo " "
echo "Adding peering for hub and spoke"
peer_create hub spoke allow-gateway-transit allow-vnet-access
peer_create spoke hub use-remote-gateways allow-vnet-access
echo " "
echo " "
echo "Creating VM in IPSEC network"
vmwpip_create 1 ipsecnetwork 22 CentOS
echo " "
echo " "
echo "Creating VM in spoke network"
vmdip_create 2 spoke 22 CentOS
;;
"8")
echo " "
echo " "
echo " "
echo " "
rg_create $choice
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode network  will be created for 192.168.114.0/24, overlapped addreses may cause issues or failure"
read -p "Press S or s then enter for silent mode  " mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create appgwvnet 192.168.114.0/24 192.168.114.0/26
subnet_add appgwvnet appgwsubnet 192.168.114.64/26
else
echo " Creating appgateway  network"
vnet_create appgwvnet
read -p "Need app gateway subnet in Vnet, Enter address prefix to use for app gateway subnet " appgwaddper
subnet_add appgwvnet appgwsubnet $appgwaddper
fi
echo " "
echo " "
echo " Adding backend VM for application gateway"
vmwpip_create 1 appgwvnet 22 UbuntuLTS
echo " "
echo " "
echo " Adding Application gateway"
server=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $3}'`
vmname=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $1}'`
if [ $appgwver == 1 ]
then
appgateway_create standard_medium  80 basic $server 
else
appgatewayv2_create standard_v2  80 basic $server
fi
echo " "
echo " "
echo "Installing NGINX in backend" 
az vm run-command invoke --subscription $reqsub --resource-group $rg_name  --name $vmname --command-id RunShellScript --scripts 'sudo apt-get install nginx -y' 1> /dev/null
az vm run-command invoke --subscription $reqsub --resource-group $rg_name  --name $vmname --command-id RunShellScript --scripts 'sudo nginx' 1> /dev/null

;;
"9")
echo " "
echo " "
echo " "
echo " "
rg_create $choice
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode network  will be created for 192.168.115.0/24, overlapped addreses may cause issues or failure"
read -p "Press S or s then enter for silent mode  " mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create appgwvnet 192.168.115.0/24 192.168.115.0/26
subnet_add appgwvnet appgwsubnet 192.168.115.64/26
else
echo " Creating appgateway  network"
vnet_create appgwvnet
read -p "Need app gateway subnet in Vnet, Enter address prefix to use for app gateway subnet " appgwaddper
subnet_add appgwvnet appgwsubnet $appgwaddper
fi
echo " "
echo " "
echo " Adding backend VM for application gateway"
vmwpip_create 1 appgwvnet 22 UbuntuLTS
echo " "
echo " "
echo " "
echo " Adding Application gateway"
server=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $3}'`
vmname=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $1}'`
if [ $appgwver == 1 ]
then
appgateway_create standard_medium 443 basic $server
else
appgatewayv2_create standard_v2 443 basic $server
fi
echo " "
echo " "
echo "Installing NGINX in backend"
az vm run-command invoke --subscription $reqsub --resource-group $rg_name  --name $vmname --command-id RunShellScript --scripts 'sudo apt-get install nginx -y' 1> /dev/null
az vm run-command invoke --subscription $reqsub --resource-group $rg_name  --name $vmname --command-id RunShellScript --scripts 'sudo nginx' 1> /dev/null
;;
"10")
echo " "
echo " "
rg_create $choice
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode network  will be created for 192.168.116.0/24, overlapped addreses may cause issues or failure"
read -p "Press S or s then enter for silent mode  " mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create appgwvnet 192.168.116.0/24 192.168.116.0/26
subnet_add appgwvnet appgwsubnet 192.168.116.64/26
else
echo " Creating appgateway  network"
vnet_create appgwvnet
read -p "Need app gateway subnet in Vnet, Enter address prefix to use for app gateway subnet " appgwaddper
subnet_add appgwvnet appgwsubnet $appgwaddper 
fi
echo " "
echo " "
echo " Adding backend VM for application gateway"
vmwpip_create 1 appgwvnet 22 UbuntuLTS
server=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $3}'`
vmname=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $1}'`
serverpip=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $2}'`
#sleep to get VM up to connection properly.
sleep 4 
if [ $appgwver == 1 ]
then
echo "  "
echo " Creating certificates"
create_cert e2e
echo " "
echo " Prepairing backend for e2e ssl"
prepare_e2evm $vmname $serverpip $server
echo " "
echo " "
echo " Adding Application gateway - This may take a bit longer as require to app gateway operation"
appgateway_create standard_medium 443 basic $server e2e
else
echo "  "
echo " Creating certificates"
create_cert e2e v2 $server
echo " "
echo " Prepairing backend for e2e ssl"
prepare_e2evm $vmname $serverpip $server
echo " "
echo " "
echo " Adding Application gateway - This may take a bit longer as require to app gateway operation"
appgatewayv2_create standard_v2 443 basic $server e2e
echo " "
echo " "
echo "      To complete the process you could need to change root certificate for HTTP settings of backend in application gateway"
echo "      Go to httpsettings uncheck use well known CA certificate and from select existing use berootcert"
echo "      Also check pick hostname from backend address"

fi
rm -rf ./tmpcert
;;
"11")
echo " "
echo " "
echo " "
echo " "
rg_create $choice
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode network  will be created for 192.168.117.0/24, overlapped addreses may cause issues or failure"
read -p "Press S or s then enter for silent mode  " mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create appgwvnet 192.168.117.0/24 192.168.117.0/26
subnet_add appgwvnet appgwsubnet 192.168.117.64/26
else
echo " Creating appgateway  network"
vnet_create appgwvnet
read -p "Need app gateway subnet in Vnet, Enter address prefix to use for app gateway subnet " appgwaddper
subnet_add appgwvnet appgwsubnet $appgwaddper
fi
echo " "
echo " "
echo " Adding backend VM for application gateway"
vmwpip_create 1 appgwvnet 22 UbuntuLTS
echo " "
echo " "
echo " "
echo " Adding Application gateway"
server=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $3}'`
vmname=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $1}'`
if [ $appgwver == 1 ]
then
appgateway_create waf_medium 443 basic $server
else
appgatewayv2_create waf_v2 443 basic $server
fi
echo " "
echo " "
echo "Installing NGINX in backend"
az vm run-command invoke --subscription $reqsub --resource-group $rg_name  --name $vmname --command-id RunShellScript --scripts 'sudo apt-get install nginx -y' 1> /dev/null
az vm run-command invoke --subscription $reqsub --resource-group $rg_name  --name $vmname --command-id RunShellScript --scripts 'sudo nginx' 1> /dev/null
rm -rf ./tmpcert
;;
"12")
echo " "
echo " "
rg_create $choice
echo " "
echo " "
echo " Press s or S and enter to create sceanrio in silent mode or enter key to run in normal mode"
echo " In Silent mode network  will be created for 192.168.118.0/24, overlapped addreses may cause issues or failure"
read -p "Press S or s then enter for silent mode  " mode
if [ "$mode" == "s" ] || [ "$mode" == "S" ]
then
echo " Creating networks"
vnet_create appgwvnet 192.168.118.0/24 192.168.118.0/26
subnet_add appgwvnet appgwsubnet 192.168.118.64/26
else
echo " Creating appgateway  network"
vnet_create appgwvnet
read -p "Need app gateway subnet in Vnet, Enter address prefix to use for app gateway subnet " appgwaddper
subnet_add appgwvnet appgwsubnet $appgwaddper
fi
echo " "
echo " "
echo " Adding backend VM for application gateway"
vmwpip_create 1 appgwvnet 22 UbuntuLTS
server=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $3}'`
vmname=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $1}'`
serverpip=`az vm list-ip-addresses --name "vm-$num-1" --subscription $reqsub --resource-group $rg_name -o table | tail -n 1 | awk '{print $2}'`
#sleep to get VM up to connection properly.
sleep 4
if [ $appgwver == 1 ]
then
  echo "  "
  echo " Creating certificates"
  create_cert e2e
  echo " "
  echo " Prepairing backend for e2e ssl"
  prepare_e2evm $vmname $serverpip $server
  echo " "
  echo " "
  echo " Adding Application gateway - This may take a bit longer as require to app gateway operation"
  appgateway_create waf_medium 443 basic $server e2e
else
  echo "  "
  echo " Creating certificates"
  create_cert e2e v2 $server
  sleep 10
  echo " "
  echo " Prepairing backend for e2e ssl"
  prepare_e2evm $vmname $serverpip $server
  echo " "
  echo " "
  echo " Adding Application gateway - This may take a bit longer as require to app gateway operation"
  appgatewayv2_create waf_v2 443 basic $server e2e 

echo "   To complete the process you could need to change root certificate for HTTP settings of backend in application gateway"
echo "   Go to httpsettings uncheck use well known CA certificate and from select existing use berootcert"
echo "    Also check pick hostname from backend address" 
  
fi
rm -rf ./tmpcert
;;
"13")
aks_precheck
#sleep 90
echo " "
echo " "
rg_create $choice
echo " "
echo " "
echo "Cloning app from git"
git clone https://github.com/Azure-Samples/azure-voting-app-redis.git
cd azure-voting-app-redis
echo "Creating docker images locally"
docker-compose up -d
echo " "
acr_create
sp_create
config_aks
rm details.txt
echo " AKS config completed" 
echo " "
echo " "
echo "Displaying pods details"
kubectl get pods
echo " "
echo " "
echo "Showing Kube details connect with http to public IP of Kube"
kubectl get service azure-vote-front
echo " "
echo " "
echo " If External IP is showing as pending please run command \" kubectl get service azure-vote-front \" to get external IP"
echo " Connect to external IP http://externalip"
exit

esac
fi
#clear
echo "                Task completed, Credentials to connect to your VM"
echo " " 
echo "                Username : - labuser" 
echo " "
echo "                Password : - p@ssw0rd123245"  
 
#done

else
exit
fi

