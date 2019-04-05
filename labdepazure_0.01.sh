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
echo " "
echo " "
echo "Enter details for  Vnet and subnet"
echo " "
echo " "
read -p "Enter the prefix for Vnet, like 192.168.0.0/24 : - " vap
echo " "
echo " "
read -p "Enter the prefix for Subnet like 192.168.0.0/24 : - " sap
#vnet=`echo  "vnet"$num`
az network vnet create --name $1 --resource-group $rg_name  --location $location --address-prefixes $vap --subnet-name subnet1 --subnet-prefixes $sap --subscription $reqsub 1> /dev/null
az network vnet list -o table
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
nsg_create nsg-$num-$1
nsgrule_create $3  nsg-$num-$1
pip_create $1 basic dynamic
az network nic create --name nic-$num$1 --resource-group $rg_name --vnet-name $2 --subnet subnet1 --public-ip-address pip-$num-$1 --network-security-group nsg-$num-$1 --location $location --subscription $reqsub 1> /dev/null
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
az network vnet peering create  --resource-group $rg_name  -n $1to$2 --vnet-name $1 --remote-vnet $2 $3  --subscription $reqsub
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
echo "===========Subscriptions in your account======================="
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
echo " 1.) Create ILB basic with single VM backend"
echo " 2.) Create Ext. LB basic with single VM backend"
echo " 3.) Standard ILB with single VM backend"
echo " 4.) Stabdard Ext. LB with single VM in backend"
echo " 5.) Standard Ext. LB with multiple VM in backend"
echo " 6.) Peered Vnets and single windows VM with PIP in each Vnet"
echo "  "
echo "  "
echo "  "
read -p "Enter scenario number " choice

case "$choice" in

"1")
echo " "
echo " "
vnet=`echo  "vnet"$num`
rg_create $choice
vnet_create $vnet
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
vnet_create $vnet
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
vnet_create $vnet
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
vnet_create $vnet
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
vnet_create $vnet
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
echo "Creating First Vnet"
vnet_create $vnet
vnet2=`echo  "vnet"$num"-2"`
echo "Creating seocnd Vnet"
vnet_create $vnet2
vmwpip_create 1 $vnet 3389 Win2016Datacenter
vmwpip_create 2 $vnet2 3389 Win2016Datacenter
echo " " 
echo " " 
echo "Adding Vnet peering"
peeringstring= `echo "--allow-forwarded-traffic"`
peer_create $vnet $vnet2  \$peeringstring
peer_create $vnet2 $vnet \$peeringstring 
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

