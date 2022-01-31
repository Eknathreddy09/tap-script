#!/bin/bash  
  
# Type: "AKS" for Azure, "EKS" for Amazon, "GKE" for Google
read -p "Enter the destination K8s cluster: " cloud
echo "##### Pivnet Token: login to tanzu network, click on your username in top right corner of the page > select Edit Profile, scroll down and click on Request New Refresh Token ######"
read -p "Enter the Pivnet token: " pivnettoken
read -p "Enter the Tanzu network username: " tanzunetusername
read -p "Enter the Tanzu network password: " tanzunetpassword
read -p "Enter the domain name for Learning center: " domainname
read -p "Enter github token (to be collected from Githubportal): " githubtoken
echo "You choose to deploy the kubernetes cluster on $cloud"
if [ "$cloud" == "AKS" ];
 then
	 
	 echo "#################  Installing AZ cli #####################"
	 curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
         echo "#########################################"
         echo "################ AZ CLI version #####################"
         az --version
         echo "############### Creating AKS Cluster #####################"
         echo "#############  Authenticate to AZ cli by following the screen Instructions below #################"
	 az login
         echo "#########################################"
         read -p "Enter the Subscription ID: " subscription
         read -p "Enter the region: " region
         echo "#########################################"
         echo "Resource group created with name tap-cluster-RG in region and subscription mentioned above"
         echo "#########################################"
	 az group create --name tap-cluster-RG --location $region --subscription $subscription
         echo "#########################################"
	 echo "Creating AKS cluster with 1 node and sku as Standard_D8S_v3, can be changed if required"
         echo "#########################################"
         az aks create --resource-group tap-cluster-RG --name tap-cluster-1 --subscription $subscription --node-count 2 --enable-addons monitoring --generate-ssh-keys --node-vm-size Standard_D8S_v3 -z 2 --enable-cluster-autoscaler --min-count 1 --max-count 2
         echo "############### Created AKS Cluster ###############"
	 echo "############### Install kubectl ##############"
	 sudo az aks install-cli
	 echo "############### Set the context ###############"
	 az account set --subscription $subscription
	 az aks get-credentials --resource-group tap-cluster-RG --name tap-cluster-1
	 echo "############## Verify the nodes #################"
	 kubectl get nodes
	 echo "###### Create RG for Repo  ######"
	 az group create --name tap-imagerepo-RG --location $region
	 echo "####### Create container registry  ############"
	 az acr create --resource-group tap-imagerepo-RG --name tapdemoacr --sku Standard
	 echo "####### Get acr Admin credentials ##########"
	 az acr update -n tapdemoacr --admin-enabled true
         acrusername=$(az acr credential show --name tapdemoacr --query "username" -o tsv)
         acrloginserver=$(az acr show --name tapdemoacr --query loginServer -o tsv)
         acrpassword=$(az acr credential show --name tapdemoacr --query passwords[0].value -o tsv)
         if grep -q "/"  <<< "$acrpassword";
             then
	        acrpassword1=$(az acr credential show --name tapdemoacr --query passwords[1].value -o tsv)
	        if grep -q "/"  <<< "$acrpassword1";
	          then
                	   echo "##########################################################################"
		  	   echo "Update the password manually in tap-values file(repopassword): password is $acrpassword1 "
                  	   echo "###########################################################################"
	        else
		   acrpassword=$acrpassword1
	        fi
         else
   	          echo "Password Updated in tap values file"
         fi
	 echo "############# Install Pivnet ###########"
	 wget https://github.com/pivotal-cf/pivnet-cli/releases/download/v3.0.1/pivnet-linux-amd64-3.0.1
	 chmod +x pivnet-linux-amd64-3.0.1
	 sudo mv pivnet-linux-amd64-3.0.1 /usr/local/bin/pivnet
         
	 echo "########## Install Tanzu CLI  #############"
	 pivnet login --api-token=${pivnettoken}
         pivnet download-product-files --product-slug='tanzu-cluster-essentials' --release-version='1.0.0' --product-file-id=1105818
	 mkdir $HOME/tanzu-cluster-essentials
	 tar -xvf tanzu-cluster-essentials-linux-amd64-1.0.0.tgz -C $HOME/tanzu-cluster-essentials
	 export INSTALL_BUNDLE=registry.tanzu.vmware.com/tanzu-cluster-essentials/cluster-essentials-bundle@sha256:82dfaf70656b54dcba0d4def85ccae1578ff27054e7533d08320244af7fb0343
	 export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
	 export INSTALL_REGISTRY_USERNAME=$tanzunetusername
	 export INSTALL_REGISTRY_PASSWORD=$tanzunetpassword
	 cd $HOME/tanzu-cluster-essentials
	 ./install.sh
	 echo "######## Install Kapp ###########"
	 sudo cp $HOME/tanzu-cluster-essentials/kapp /usr/local/bin/kapp
         kapp version
	 echo "#################################"
         pivnet download-product-files --product-slug='tanzu-application-platform' --release-version='1.0.0' --product-file-id=1114447
	 mkdir $HOME/tanzu
         tar -xvf tanzu-framework-linux-amd64.tar -C $HOME/tanzu
	 export TANZU_CLI_NO_INIT=true
	 cd $HOME/tanzu
         sudo install cli/core/v0.10.0/tanzu-core-linux_amd64 /usr/local/bin/tanzu
         tanzu version
	 tanzu plugin install --local cli all
         tanzu plugin list
	 echo "######### Prepare the tap-values file ##########"
         sed -i -r "s/tanzunetusername/$tanzunetusername/g" "$HOME/tap-script/tap-values.yaml"
	 sed -i -r "s/tanzunetpassword/$tanzunetpassword/g" "$HOME/tap-script/tap-values.yaml"
	 sed -i -r "s/registry/$acrloginserver/g" "$HOME/tap-script/tap-values.yaml"
	 sed -i -r "s/repousername/$acrusername/g" "$HOME/tap-script/tap-values.yaml"
	 sed -i -r "s/repopassword/$acrpassword/g" "$HOME/tap-script/tap-values.yaml"
	 sed -i -r "s/domainname/$domainname/g" "$HOME/tap-script/tap-values.yaml"
	 sed -i -r "s/githubtoken/$githubtoken/g" "$HOME/tap-script/tap-values.yaml"
	 echo "######### Install Docker ############"
	 sudo apt-get update
	 sudo apt-get install  ca-certificates curl  gnupg  lsb-release
	 curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
	 echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
	 sudo apt-get update
	 sudo apt-get install docker-ce docker-ce-cli containerd.io -y
	 sudo usermod -aG docker $USER
         echo "####### Verify Docker Version  ###########"
         sudo reboot

elif [ "$cloud" == "EKS" ];
 then
	 
         echo "#########################################"
         echo "#########################################"
	 echo "Installing AWS cli"
         echo "#########################################"
         echo "#########################################"
         curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
         sudo apt install unzip
	 unzip awscliv2.zip
	 sudo ./aws/install
	 ./aws/install -i /usr/local/aws-cli -b /usr/local/bin
         echo "#########################################"
         echo "AWS CLI version"
         echo "#########################################"
	 aws --version
         echo "#########################################"
         echo "#########################################"


elif [ "$cloud" == "GKE" ];
 then
         echo "#########################################"
         echo "#########################################"
	 echo "Installing GKE cli"
         echo "#########################################"
         echo "#########################################"
	 sudo apt-get install apt-transport-https ca-certificates gnupg
	 echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
	 curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
	 sudo apt-get update && sudo apt-get install google-cloud-sdk
         echo "#########################################"
	 echo "Authenticate to Gcloud by following the screen Instructions below"
         echo "#########################################"
         echo "#########################################"
	 gcloud init
         echo "#########################################"
         echo "gloud CLI version"
         echo "#########################################"
	 gcloud version
         echo "#########################################"
         echo "#########################################"
fi
echo "I am done here"
