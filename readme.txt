Script is created by Amit Anand


----------- 0.01--------------------------------------------------------------04/04/19
This script is to help creating Different deployments in Azure for testing purpose / lab scenarios 

Prereq you need to be signed in to your Azure account before running the script. 

#az login

Once logged in run this script as 
chmod +x labdepazure_0.01.sh

./labdepazure_0.01.sh

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
