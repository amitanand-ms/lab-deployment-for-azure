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

5.)	./labdepazure_<ver>.sh

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

5.)	./labdepazure_<ver>.sh

e.g. ./labdepazure_0.02.sh


Once Sript is running.

-> At first step it shows all subscriptions in your account and you could select the subscription to use by entering number against it. 

-> After that you need to enter number of the scenario you want to create. 

-> This script will create a resource group by name scenario<num of choosen scenario>_randomnum like scenario1_99999

All related resources related to scenario woudl be created in this resource group. 

Script will take care of opening related ports for accessing resources based on selection. 

i.e. if the VM OS is selected port 22,80,443 would be open. In case of Windows 3389, 80,443 would be open. 

->For External LB related scenarios this will also add rules for specific ports i.e. port 22 or 3389 so that you could connect to VMs behind LB through LB. 

->For internal LB related scenarios VMs would have direct PIP on them to connect to VMs. 

-> For scenario where you create multiple Vms behind standard LB this will add a LB rule for port 80, and each VM woudl be reachable through NAT rule, using ports 10001 - 1000n depening of number of VMs you choose while creating scenario. 

-> Vnet peering right now is peering in two Vnets having windows VM in each VM with PIP

-> Default credentials to login to your VM are user: - labuser , password: - p@ssw0rd12345
