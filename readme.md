Script is created by Amit Anand


Introduction


This Program is created to help engineers and admins to quickly spin to different deployments for lab and testing purpose. To help everyone with visualizing resources and what are the different components needs to be set to make things working in such Scenarios.
This is to expedite lab repro and scenario testing. 

How it works


This will create a new resource group; name of resource group is combination of number of the scenario you choose along with a random number.  To maintain multiple deployment of same scenarios. 
And all the resources required based on scenarios would be created in same resource groups.
From 0.02 version onwards users would have flexibility to use silent mode which make program to use predefined set of network prefixes. Thus, would need even fewer inputs form user and there would be no need to calculate correct subnets for scenario creation as well. 
While creating the scenarios Program also takes care of NSG ports based on the selection of OS. With Windows 3389,80,443 gets open. With Linux 22,80,443 gets open. 

Steps to use. 

On Linux PCs. 

One time step if you do not have AZ CLI already on your PC. 
1.)	Install AZ CLI on your Linux OS
Depending on your OS type
https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest

Steps to run script
       1.)  SSH to your Linux PC.
2.)	Copy script to a folder and unzip it using unzip command.
Wget  https://github.com/amitanand-ms/lab-deployment-for-azure/archive/master.zip
Unzip master.zip 
3.)	Change directory to program directory

cd lab-deployment-for-azure-master

4.)	chmod +x labdepazure_<ver>.sh

Like 

Chmod +x labdepazure_0.02.sh

5.)  Sign in to your Azure azzount from az cli

   az login
   
6.)	./labdepazure_<ver>.sh

e.g. ./labdepazure_0.02.sh

On Windows PC. 
One-time step if you do not have linux sub system already installed on your windows.
1.)	Install Linux Subsystem for windows. 

          https://docs.microsoft.com/en-us/windows/wsl/install-win10

2.)	Open linux shell and based on your linux sub system flavor install AZ CLI module on it. 

https://docs.microsoft.com/en-us/cli/azure/install-azure-cli?view=azure-cli-latest


Once you have AZ CLI installed on the linux subsystem on windows. 

1.)	Open linux subsystem on Windows. 

2.)	Copy script to a folder and unzip it using unzip command.
Wget  https://github.com/amitanand-ms/lab-deployment-for-azure/archive/master.zip
Unzip master.zip 
3.)	Change directory to program directory

cd lab-deployment-for-azure-master

4.)	chmod +x labdepazure_<ver>.sh

Like 

Chmod +x labdepazure_0.02.sh

5.) Sign in to your Azure azzount from az cli

   az login

6.)	./labdepazure_<ver>.sh

e.g. ./labdepazure_0.02.sh



Once Sript is running.

-> At first step it shows all subscriptions in your account and you could select the subscription to use by entering number against it. 

-> After that you need to enter number of the scenario you want to create. 

-> This script will create a resource group by name scenario<num of choosen scenario>_randomnum like scenario1_99999

All related resources related to scenario woudl be created in this resource group. 

Script will take care of opening related ports for accessing resources based on selection. 

i.e. if the VM OS is selected port 22,80,443 would be open. In case of Windows 3389, 80,443 would be open. 

Scenarios Corevered Presently.
 1.) Create ILB basic with single VM backend
 Creates an internal Basic LB with a single VM behind it in backend pool. Since this is ILB VM would have PIP for connectivity. 
 
 2.) Create Ext. LB basic with single VM backend
 Creates External basic LB with single VM in backend, connectivity to VM would be through LB based on OS you choose i.e. Linux or windows. 
 
 3.) Standard ILB with single VM backend
 Creates an internal Standard LB with a single VM behind it in backend pool. Since this is ILB VM would have PIP for connectivity.
  
 4.) Stabdard Ext. LB with single VM in backend
 Creates External standard LB with single VM in backend, connectivity to VM would be through LB based on OS you choose i.e. Linux or windows.
 
 5.) Standard Ext. LB with multiple VM in backend
 Creates External standard LB with multiple VM in backend, connectivity to VM would be through LB based on OS you choose i.e. Linux or windows. User woudl need to enter number of VMs in backend pool and this will also create NAT rules to connect to VM based on choice of OS. 
 
 6.) Peered Vnets and single windows VM with PIP in each Vnet
 Creates two peered Vnets and windows VM in each vnet with PIP on them. 
 
 7.) Hub spoke model along with IPSEC connected Vnet with hub
 Creates 3 Vnets hub, spoke and IPSEC. Ipsec Vnets would be connected through IPsec connection to hub vnet through VPN gateways. And Spoke would be peered as use remote gateways to hub. 
 It will create VM with PIP in IPSEC Vnet and with just Local IP in Spoke Vnet. And these VMs would be able to connect to each other though hub spoke model using ipsec connection. Just like with an onprem network using hub spoke model. 
 
