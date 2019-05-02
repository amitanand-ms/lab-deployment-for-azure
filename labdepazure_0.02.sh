#!/bin/bash
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
echo $rg_name
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
az network public-ip create --name pip-$num-$1 --sku $2 --location $location --subscription $reqsub --resource-group $rg_name --allocation-method $3 1> /dev/null
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
         az vm create --name vm-$num$i --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image ${args[$x+3]}  --license-type none --size $chksize  --nics  nic-$num$i  --subscription $reqsub --location $location 1> /dev/null
         else
         az vm create --name vm-$num$i --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image ${args[$x+3]} --size $chksize  --nics  nic-$num$i  --subscription $reqsub --location $location 1> /dev/null
fi
else
echo " Creating VM " $i
nsg_create nsg-$num-$i
nsgrule_create $p  nsg-$num-$i
pip_create $i basic dynamic
az network nic create --name nic-$num$i --resource-group $rg_name --vnet-name $v --subnet subnet1 --public-ip-address pip-$num-$i --network-security-group nsg-$num-$i --location $location --subscription $reqsub 1> /dev/null
if  [ "$img" == "Win" ]
        then
         az vm create --name vm-$num$i --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image ${args[$x+3]}  --license-type none --size $chksize  --nics  nic-$num$i  --subscription $reqsub --location $location 1> /dev/null&
         else
         az vm create --name vm-$num$i --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image ${args[$x+3]} --size $chksize  --nics  nic-$num$i  --subscription $reqsub --location $location 1> /dev/null&
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
         az vm create --name vm-$num$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $4  --license-type none --size $chksize  --nics  nic-$num$1  --subscription $reqsub --location $location 1> /dev/null
         else
         az vm create --name vm-$num$1 --location $location --resource-group $rg_name --admin-username labuser --admin-password p@ssw0rd12345 --image $4 --size $chksize  --nics  nic-$num$1  --subscription $reqsub --location $location 1> /dev/null
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
echo " "
echo " "
echo "Creating connection for " $1 " to " $2
az network vpn-connection create --name ipsec-connection-$1-$2 --vnet-gateway1 $1 --local-gateway2 $2 --shared-key abc123 --location $location --resource-group $rg_name --subscription $reqsub 1> /dev/null
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

read -p "Enter the number of subscription you want to create resourcei in or q to exit " snum
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
echo -e "\e[1;38m 1.) Create ILB basic with single VM backend"
echo -e "\e[1;38m 2.) Create Ext. LB basic with single VM backend"
echo -e "\e[1;38m 3.) Standard ILB with single VM backend"
echo -e "\e[1;38m 4.) Stabdard Ext. LB with single VM in backend"
echo -e "\e[1;38m 5.) Standard Ext. LB with multiple VM in backend"
echo -e "\e[1;38m 6.) Peered Vnets and single windows VM with PIP in each Vnet"
echo -e "\e[1;38m 7.) Hub spoke model along with IPSEC connected Vnet with hub"
echo "  "
echo "  "
echo "  "
echo -e "\e[1;38m Enter scenario number "
read -p "                                " choice

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
peer_create $vnet $vnet2  
peer_create $vnet2 $vnet 
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
esac
fi
clear
echo "                Task completed, Credentials to connect to your VM"
echo " " 
echo "                Username : - labuser" 
echo " "
echo "                Password : - p@ssw0rd123245"  
 
#done

else
exit
fi

