Unofficial TAP 1.0 install script, this is written out of my personal Interest. 

# tap-script
Deploy an ubuntu machine with minimum config                                                                                                                                                                              
Git clone https://github.com/Eknathreddy09/tap-script                                                                                
Navigate to directory > $HOME/tap-script                                          
Run ./tap-script.sh                                                                     
Enter the values : AKS or EKS or GKE, Tanzu network token, Tanzu net username, Tanzu net password, Github Token, Domain name (for learning portal)                
AWS:                                                
                  Provide Docker hub credentials 
                  Enter the values: AWS access keys, Region                                               
GKE:                                            
                  Authenticate to GCP by following the screen Instructions                                                          
                 
AKS:                                                            
      Authenticate to Azure by following the screen Instructions
      Enter the values: Subscription ID, Region

Run ./tap-install.sh  #This script includes the TAP packages install, Update tap-gui with LB, Deploy sample application. 
