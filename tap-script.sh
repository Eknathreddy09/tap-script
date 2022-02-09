#!/bin/bash  
  
echo "######################## Type: AKS for Azure, EKS for Amazon, GKE for Google ########################"
echo "############################ If you choose EKS, Keep docker.io credentials handy ######################"
read -p "Enter the destination K8s cluster: " cloud
echo "#####################################################################################################"
echo "##### Pivnet Token: login to tanzu network, click on your username in top right corner of the page > select Edit Profile, scroll down and click on Request New Refresh Token ######"
read -p "Enter the Pivnet token: " pivnettoken
read -p "Enter the Tanzu network username: " tanzunetusername
read -p "Enter the Tanzu network password: " tanzunetpassword
read -p "Enter the domain name for Learning center: " domainname
read -p "Enter github token (to be collected from Githubportal): " githubtoken
echo " ######  You choose to deploy the kubernetes cluster on $cloud ########"
echo "#####################################################################################################"
if [ "$cloud" == "AKS" ];
 then
	 
	 echo "#################  Installing AZ cli #####################"
	 curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash
         echo "#########################################"
         echo "################ AZ CLI version #####################"
         az --version
         echo "############### Creating AKS Cluster #####################"
         echo "#####################################################################################################"
         echo "#############  Authenticate to AZ cli by following the screen Instructions below #################"
         echo "#####################################################################################################"
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
         az aks create --resource-group tap-cluster-RG --name tap-cluster-1 --subscription $subscription --node-count 2 --enable-addons monitoring --generate-ssh-keys --node-vm-size Standard_D8S_v3 -z 1 --enable-cluster-autoscaler --min-count 1 --max-count 2
         echo "############### Created AKS Cluster ###############"
	 echo "############### Install kubectl ##############"
	 sudo az aks install-cli
	 echo "############### Set the context ###############"
	 az account set --subscription $subscription
	 az aks get-credentials --resource-group tap-cluster-RG --name tap-cluster-1
	 echo "############## Verify the nodes #################"
         echo "#####################################################################################################"
	 kubectl get nodes
         echo "#####################################################################################################"
	 echo "###### Create RG for Repo  ######"
	 az group create --name tap-imagerepo-RG --location $region
	 echo "####### Create container registry  ############"
         echo "#####################################################################################################"
	 az acr create --resource-group tap-imagerepo-RG --name tapdemoacr --sku Standard
	 echo "####### Fetching acr Admin credentials ##########"
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
         echo "######### Preparing the tap-values file ##########"
         sed -i -r "s/tanzunetusername/$tanzunetusername/g" "$HOME/tap-script/tap-values.yaml"
         sed -i -r "s/tanzunetpassword/$tanzunetpassword/g" "$HOME/tap-script/tap-values.yaml"
         sed -i -r "s/registryname/$acrloginserver/g" "$HOME/tap-script/tap-values.yaml"
         sed -i -r "s/repousername/$acrusername/g" "$HOME/tap-script/tap-values.yaml"
         sed -i -r "s/repopassword/$acrpassword/g" "$HOME/tap-script/tap-values.yaml"
         sed -i -r "s/domainname/$domainname/g" "$HOME/tap-script/tap-values.yaml"
         sed -i -r "s/githubtoken/$githubtoken/g" "$HOME/tap-script/tap-values.yaml"
         echo "#####################################################################################################"
         echo "########### Creating Secrets in tap-install namespace  #############"
         kubectl create ns tap-install
         kubectl create secret docker-registry registry-credentials --docker-server=$acrloginserver --docker-username=$acrusername --docker-password=$acrpassword -n tap-install
         kubectl create secret docker-registry image-secret --docker-server=$acrloginserver --docker-username=$acrusername --docker-password=$acrpassword -n tap-install
elif [ "$cloud" == "EKS" ];
 then
	 read -p "Enter the region: " region
         read -p "Enter the dockerhub username: " dockerusername
         read -p "Enter the dockerhub password: " dockerpassword
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
         echo "############# Provide AWS access key and secrets  ##########################"
         aws configure
         read -p "Enter AWS session token: " aws_token
         aws configure set aws_session_token $aws_token
         echo "############ Install Kubectl #######################"
         curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
         sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
         echo "############  Kubectl Version #######################"
         kubectl version
         echo "################## Creating IAM Roles for EKS Cluster and nodes ###################### "
cat <<EOF > cluster-role-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "eks.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

cat <<EOF > node-role-trust-policy.json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Principal": {
        "Service": "ec2.amazonaws.com"
      },
      "Action": "sts:AssumeRole"
    }
  ]
}
EOF

aws iam create-role --role-name tap-EKSClusterRole --assume-role-policy-document file://"cluster-role-trust-policy.json"
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKSClusterPolicy --role-name tap-EKSClusterRole
aws iam create-role --role-name tap-EKSNodeRole --assume-role-policy-document file://"node-role-trust-policy.json"
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy --role-name tap-EKSNodeRole
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly --role-name tap-EKSNodeRole
aws iam attach-role-policy --policy-arn arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy --role-name tap-EKSNodeRole

echo "########################### Creating VPC Stacks through cloud formation ##############################"

aws cloudformation create-stack --region $region --stack-name tap-demo-vpc-stack --template-url https://amazon-eks.s3.us-west-2.amazonaws.com/cloudformation/2020-10-29/amazon-eks-vpc-private-subnets.yaml
echo "############## Waiting for VPC stack to get created ###################"
echo "############## Paused for 5 mins ##########################"
sleep 5m
pubsubnet1=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=tap-demo-vpc-stack-PublicSubnet01 --query Subnets[0].SubnetId --output text)
pubsubnet2=$(aws ec2 describe-subnets --filters Name=tag:Name,Values=tap-demo-vpc-stack-PublicSubnet02 --query Subnets[0].SubnetId --output text)
rolearn=$(aws iam get-role --role-name tap-EKSClusterRole --query Role.Arn --output text)
sgid=$(aws ec2 describe-security-groups --filters Name=description,Values="Cluster communication with worker nodes" --query SecurityGroups[0].GroupId --output text)

echo "########################## Creating EKS Cluster ########################################"

ekscreatecluster=$(aws eks create-cluster --region $region --name tap-demo-ekscluster --kubernetes-version 1.21 --role-arn $rolearn --resources-vpc-config subnetIds=$pubsubnet1,$pubsubnet2,securityGroupIds=$sgid)

echo "############## Waiting for EKS cluster to get created ###################"
echo "############## Paused for 15 mins ###############################"
sleep 15m
aws eks update-kubeconfig --region $region --name tap-demo-ekscluster

rolenodearn=$(aws iam get-role --role-name tap-EKSNodeRole --query Role.Arn --output text)
echo "######################### Creating Node Group ###########################"
aws eks create-nodegroup --cluster-name tap-demo-ekscluster --nodegroup-name tap-demo-eksclusterng --node-role $rolenodearn --instance-types t2.2xlarge --scaling-config minSize=1,maxSize=2,desiredSize=2 --disk-size 40  --subnets $pubsubnet1

echo "############## Waiting for Node groups to get created ###################"
echo "############### Paused for 10 mins ################################"
sleep 10m
echo "################ Prepare Tap values file ##################"
#aws ecr create-repository --repository-name tapdemoacr
#ecrusername=AWS
#ecrpassword=$(aws ecr get-login-password --region $region)
#ecrregistryid=$(aws ecr describe-repositories --repository-names tapdemoacr --query repositories[0].registryId --output text)
#ecrloginserver=$ecrregistryid.dkr.ecr.$region.amazonaws.com
cat <<EOF > tap-values.yaml
profile: full
ceip_policy_disclosed: true # Installation fails if this is set to 'false'
buildservice:
  kp_default_repository: "index.docker.io/$dockerusername/build-service" # Replace the project id with yours. In my case eknath-se is the project ID
  kp_default_repository_username: $dockerusername
  kp_default_repository_password: $dockerpassword
  tanzunet_username: "$tanzunetusername" # Provide the Tanzu network user name
  tanzunet_password: "$tanzunetpassword" # Provide the Tanzu network password
  descriptor_name: "tap-1.0.0-full"
  enable_automatic_dependency_updates: true
supply_chain: testing_scanning
ootb_supply_chain_testing_scanning:
  registry:
    server: "index.docker.io"
    repository: "$dockerusername" # Replace the project id with yours. In my case eknath-se is the project ID
  gitops:
    ssh_secret: ""
  cluster_builder: default
  service_account: default

learningcenter:
  ingressDomain: "$domainname" # Provide a Domain Name

metadata_store:
  app_service_type: LoadBalancer # (optional) Defaults to LoadBalancer. Change to NodePort for distributions that don't support LoadBalancer
grype:
  namespace: "tap-install" # (optional) Defaults to default namespace.
  targetImagePullSecret: "registry-credentials"
contour:
  envoy:
    service:
      type: LoadBalancer
tap_gui:
  service_type: LoadBalancer # NodePort for distributions that don't support LoadBalancer
  app_config:
    app:
      baseUrl: http://lbip:7000
    integrations:
      github: # Other integrations available see NOTE below
        - host: github.com
          token: $githubtoken  # Create a token in github
    catalog:
      locations:
        - type: url
          target: https://github.com/Eknathreddy09/tanzu-java-web-app/blob/main/catalog/catalog-info.yaml
    backend:
      baseUrl: http://lbip:7000
      cors:
        origin: http://lbip:7000
EOF
         echo "#####################################################################################################"
         echo "########### Creating Secrets in tap-install namespace  #############"
kubectl create ns tap-install
kubectl create secret docker-registry registry-credentials --docker-server=https://index.docker.io/v1/ --docker-username=$dockerusername --docker-password=$dockerpassword -n tap-install
kubectl create secret docker-registry image-secret --docker-server=https://index.docker.io/v1/ --docker-username=$dockerusername --docker-password=$dockerpassword -n tap-install
#        echo "######### Prepare the tap-values file ##########"
#        sed -i -r "s/tanzunetusername/$tanzunetusername/g" "$HOME/tap-script/tap-values.yaml"
#        sed -i -r "s/tanzunetpassword/$tanzunetpassword/g" "$HOME/tap-script/tap-values.yaml"
#        sed -i -r "s/registryname/$ecrloginserver/g" "$HOME/tap-script/tap-values.yaml"
#        sed -i -r "s/repousername/$ecrusername/g" "$HOME/tap-script/tap-values.yaml"
#        sed -i -r "s/repopassword/$ecrpassword/g" "$HOME/tap-script/tap-values.yaml"
#        sed -i -r "s/domainname/$domainname/g" "$HOME/tap-script/tap-values.yaml"
#        sed -i -r "s/repousername/$dockerusername/g" "$HOME/tap-script/tap-values.yaml"
#        sed -i -r "s/repopassword/$dockerpassword/g" "$HOME/tap-script/tap-values.yaml"
#        sed -i -r "s/githubtoken/$githubtoken/g" "$HOME/tap-script/tap-values.yaml"
elif [ "$cloud" == "GKE" ];
 then
         echo "#########################################"
         echo "#########################################"
	 echo "Installing GKE cli"
         echo "#########################################"
         echo "#########################################"
	 sudo apt-get install apt-transport-https ca-certificates gnupg -y
	 echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | sudo tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
	 curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
	 sudo apt-get update && sudo apt-get install google-cloud-sdk -y
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
         echo "############ Installing Kubectl #######################"
         curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
         sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
         echo "############  Kubectl Version #######################"
         kubectl version
         region=$(gcloud config get-value compute/region)
         echo "############################## Creating GKE Clusters ###############################"
         gcloud container clusters create --machine-type e2-standard-8 --num-nodes 1 --cluster-version latest --region=$region tap-demo-gkecluster
         echo "######################## Creating GCR Repo ##########################"
         gcloud iam service-accounts create tap-demo-gcrrepo --display-name="For TAP Images"
         projid=$(gcloud config get-value project)
         gcloud iam service-accounts keys create tap-demo-cred.json --iam-account=tap-demo-gcrrepo@$projid.iam.gserviceaccount.com
         gsutil ls
         gsutil iam ch serviceAccount:tap-demo-gcrrepo@$projid.iam.gserviceaccount.com:legacyBucketWriter gs://artifacts.$projid.appspot.com/
         kubectl create ns tap-install
         echo "######### Preparing the tap-values file ##########"
         projid=$(gcloud config get-value project)
service_account_key="$(cat tap-demo-cred.json)"
cat <<EOF > tap-values.yaml
profile: full
ceip_policy_disclosed: true # Installation fails if this is set to 'false'
buildservice:
  kp_default_repository: "gcr.io/$projid/build-service" # Replace the project id with yours. In my case eknath-se is the project ID
  kp_default_repository_username: _json_key
  kp_default_repository_password: '$(echo $service_account_key)'
  tanzunet_username: "$tanzunetusername" # Provide the Tanzu network user name
  tanzunet_password: "$tanzunetpassword" # Provide the Tanzu network password
  descriptor_name: "tap-1.0.0-full"
  enable_automatic_dependency_updates: true
supply_chain: testing_scanning
ootb_supply_chain_testing_scanning:
  registry:
    server: "gcr.io"
    repository: "$projid/supply-chain" # Replace the project id with yours. In my case eknath-se is the project ID
  gitops:
    ssh_secret: ""
  cluster_builder: default
  service_account: default

learningcenter:
  ingressDomain: "$domainname" # Provide a Domain Name

metadata_store:
  app_service_type: LoadBalancer # (optional) Defaults to LoadBalancer. Change to NodePort for distributions that don't support LoadBalancer
grype:
  namespace: "tap-install" # (optional) Defaults to default namespace.
  targetImagePullSecret: "registry-credentials"
contour:
  envoy:
    service:
      type: LoadBalancer
tap_gui:
  service_type: LoadBalancer # NodePort for distributions that don't support LoadBalancer
  app_config:
    app:
      baseUrl: http://lbip:7000
    integrations:
      github: # Other integrations available see NOTE below
        - host: github.com
          token: $githubtoken  # Create a token in github
    catalog:
      locations:
        - type: url
          target: https://github.com/Eknathreddy09/tanzu-java-web-app/blob/main/catalog/catalog-info.yaml
    backend:
      baseUrl: http://lbip:7000
      cors:
        origin: http://lbip:7000
EOF
         echo "#####################################################################################################"
         echo "########### Creating Secrets in tap-install namespace  #############"
kubectl create secret docker-registry registry-credentials --docker-server=gcr.io --docker-username=_json_key --docker-password="$(cat tap-demo-cred.json)" -n tap-install
kubectl create secret docker-registry image-secret --docker-server=gcr.io --docker-username=_json_key --docker-password="$(cat tap-demo-cred.json)" -n tap-install
fi
     echo "############# Installing Pivnet ###########"
     wget https://github.com/pivotal-cf/pivnet-cli/releases/download/v3.0.1/pivnet-linux-amd64-3.0.1
     chmod +x pivnet-linux-amd64-3.0.1
     sudo mv pivnet-linux-amd64-3.0.1 /usr/local/bin/pivnet
         
     echo "########## Installing Tanzu CLI  #############"
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
     echo "######## Installing Kapp ###########"
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
     echo "######### Installing Docker ############"
     sudo apt-get update
     sudo apt-get install  ca-certificates curl  gnupg  lsb-release
     curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
     echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
     sudo apt-get update
     sudo apt-get install docker-ce docker-ce-cli containerd.io -y
     sudo usermod -aG docker $USER
         echo "####### Verify Docker Version  ###########"
         sudo apt-get install jq -y
         export INSTALL_REGISTRY_USERNAME=$tanzunetusername
         export INSTALL_REGISTRY_PASSWORD=$tanzunetpassword
         export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com
         tanzu secret registry add tap-registry --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} --server ${INSTALL_REGISTRY_HOSTNAME} --export-to-all-namespaces --yes --namespace tap-install
         echo "#####################################################################################################"
         echo "########### Rebooting #############"
         sudo reboot
