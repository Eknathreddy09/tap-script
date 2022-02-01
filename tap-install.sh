#!/bin/bash

read -p "Enter the Tanzu network username: " tanzunetusername
read -p "Enter the Tanzu network password: " tanzunetpassword
export INSTALL_REGISTRY_USERNAME=$tanzunetusername
export INSTALL_REGISTRY_PASSWORD=$tanzunetpassword
export INSTALL_REGISTRY_HOSTNAME=registry.tanzu.vmware.com

echo "################# Create namespace ###########################"
kubectl create ns tap-install

echo "################# Create secret tap-registry ##############################"
tanzu secret registry add tap-registry --username ${INSTALL_REGISTRY_USERNAME} --password ${INSTALL_REGISTRY_PASSWORD} --server ${INSTALL_REGISTRY_HOSTNAME} --export-to-all-namespaces --yes --namespace tap-install

echo "############# Add Tanzu Application Platform package repository to the cluster ####################"
tanzu package repository add tanzu-tap-repository --url registry.tanzu.vmware.com/tanzu-application-platform/tap-packages:1.0.0 --namespace tap-install
tanzu package repository get tanzu-tap-repository --namespace tap-install
echo "############# List the available packages ####################"
tanzu package available list --namespace tap-install

echo "############### TAP 1.0 Install   ##################"
tanzu package install tap -p tap.tanzu.vmware.com -v 1.0.0 --values-file $HOME/tap-script/tap-values.yaml -n tap-install
tanzu package installed list -A 
reconcilestat=$(tanzu package installed list -A -o json | jq '.[].status')

echo "############## Get the package install status #################"
for 
tanzu package installed get tap -n tap-install
sleep 20m

ip=$(kubectl get svc -n tap-gui -o=jsonpath='{.items[0].status.loadBalancer.ingress[0].ip}')
sed -i -r "s/lbip/$ip/g" "$HOME/tap-script/tap-values.yaml"
tanzu package installed update tap --package-name tap.tanzu.vmware.com --version 1.0.0 -n tap-install -f $HOME/tap-script/tap-values.yaml
