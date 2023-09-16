# JCNR-In-Server Setup Guide

This guide assists in setting up a DPDK app running environment, specifically for the Juniper Cloud-Native Router (JCNR). This setup is designed for a standalone JCNR in a server, primarily intended for demonstration purposes. It's important to note that this setup is not intended for production deployment.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Overview

The scripts provided will help establish a running environment that includes requirements like Huge Page, VFIO/VFIO-PCI drivers, and necessary kernel modules for cRPD.

Once set up, a reboot will be required to apply changes made to grub and the hugepage size settings. Additionally, the script installs an All-in-One Kubernetes cluster using minikube. The Kubernetes node will receive a label either from user input or a default value to identify it as the target node for JCNR. Various tools, including helm, kubectl, k9s, and others will be automatically installed.

## Prerequisites

- Ubuntu server 22.04
- Basic knowledge of Kubernetes
- Basic knowledge of Ubuntu Linux
- JCNR package file downloaded

**Note:** The installation scripts and steps provided are tested and specifically designed for Ubuntu server 22.04.

## Installation

1. Clone the repository:
```bash
git clone https://github.com/simonrho/jcnr-in-server.git
```
2. Navigate to the repository directory and run the setup script with root privileges:
```bash
cd jcnr-in-server
sudo ./setup.sh
```

## Directory Structure

```
. 
├── LICENSE.txt 
├── README.md 
├── setup.sh 
└── ubuntu 
    └── scripts 
        ├── create-jcnr-secrets.sh 
        ├── create-label-update-values.sh 
        ├── install-dpdk-env.sh 
        ├── install-k8s.sh 
        ├── install-tools.sh 
        └── load-jcnr-images.sh 
```

## File Descriptions

{setup.sh}: Initiates the installation of the DPDK app environment, Kubernetes, and JCNR.  
{install-dpdk-env.sh}: Establishes the DPDK app running environment.  
{install-k8s.sh}: Handles the installation of an all-in-one Kubernetes cluster.  
{install-tools.sh}: Automates the installation of required tools such as kubectl, helm, and k9s.  
{create-jcnr-secrets.sh}: Constructs the Kubernetes secrets manifest for JCNR license and root password.  
{create-label-update-values.sh}: Tags the node with key/value, designating it as the JCNR running target.  
{load-jcnr-images.sh}: Loads the JCNR container images into the local repository.  

## License and Password for JCNR

If a default `jcnr-license.txt` file and `jcnr-root-password.txt` file are present in the directory, they will be used to automatically generate the `jcnr-secrets.yaml` file. If these default files are not found, you will be prompted to provide the JCNR root password and license key. This will be used to build the secrets file and apply it to Kubernetes.

## JCNR-in-Server Setup Terminal Recording

[![asciicast](https://asciinema.org/a/F3MEPuWz9ZowZ905hImNH8BJp.png)]( https://asciinema.org/a/F3MEPuWz9ZowZ905hImNH8BJp)

## Setup Output Sections

### 1. Initial Setup & System Reboot

This section provides feedback on the setup related to DPDK environment preparation, including netplan configuration, Linux extra modules installation, cRPD related modules configuration, and more. At the end of this step, a system reboot is recommended.
```bash
# git clone https://github.com/simonrho/jcnr-in-server.git
Cloning into 'jcnr-in-server'...
remote: Enumerating objects: 13, done.
remote: Counting objects: 100% (13/13), done.
remote: Compressing objects: 100% (13/13), done.
remote: Total 13 (delta 0), reused 13 (delta 0), pack-reused 0
Receiving objects: 100% (13/13), 13.27 KiB | 6.64 MiB/s, done.
# 
# cd jcnr-in-server/ubuntu
#
# sudo echo "<jcnr-root-password>" > jcnr-root-password.txt
# sudo echo "<jcnr-license-key>" > jcnr-license.txt
#
# ls Juniper_Cloud_Native_Router*.tgz
Juniper_Cloud_Native_Router_23.2.tgz
#
# sudo ./setup.sh 

Running install-dpdk-env.sh.
Logging install steps to install-dpdk-env.log.
Netplan configuration done.
Installing Linux extra modules. It will take a few minutes. Please be patient.
Linux extra modules installed.
cRPD related modules configuration done.
VFIO modules configuration done.
VFIO extra option setup done.
THP disabled.
Huge Pages setup complete.
GRUB updated.
Installation completed. Check install-dpdk-env.log for detailed logs.
Reboot now? (y/N): (You have 10 seconds to respond. Default is Y): Y
Connection to ec2-54-186-82-174.us-west-2.compute.amazonaws.com closed by remote host.
Connection closed.

```
### 2. Kubernetes Installation & JCNR Installation

After rebooting, running the setup script again will proceed with Kubernetes cluster setup, including Docker, cri-dockerd, CNI plugins, and minikube installation. This is then followed by JCNR installation, which involves loading the JCNR images, creating Kubernetes secrets for JCNR, and updating the `values.yaml` file based on user input or default settings.
```bash
./setup.sh 
This script has previously been executed and the system rebooted.

Running install-k8s.sh.
Logging install steps to install-k8s.log.
Installing Docker...
Installing cri-dockerd...
Installing crictl...
Installing CNI plugins...
Installing minikube...
Create /usr/local/bin/kubectl soft-link...
Installing multus cni...
Installation completed. Check install-k8s.log for detailed logs.

Running install-tools.sh
Logging install steps to install-tools.log
kubectl is already installed.
Installing Helm...
Installing k9s...
All required tools are installed.

Running load-jcnr-images.sh.
Found tar file: Juniper_Cloud_Native_Router_23.2.tgz.
Extracting the file: Juniper_Cloud_Native_Router_23.2.tgz...
Found Docker image file: ./Juniper_Cloud_Native_Router_23.2/images/jcnr-images.tar.gz.
Loading Docker image..../Juniper_Cloud_Native_Router_23.2/images/jcnr-images.tar.gz.
Docker image loaded successfully!

Running create-jcnr-secrets.sh
This script will use default files for license & root password if present:
Default License File: jcnr-license.txt
Default Root Password File: jcnr-root-password.txt
If these files are not found, you will be prompted for input.
---------------------------------------
Reading root password from jcnr-root-password.txt.
Reading license key from jcnr-license.txt.
Creating jcnr-secrets.yaml file.
Applying JCNR secrets and namespace.
namespace/jcnr created
secret/jcnr-secrets created

Running create-label-update-values.sh.
Enter label in format key=value (You have 30 seconds to respond. Default is key1=jcnr): Adding label key1=jcnr to the node k1.
node/k1 labeled
Updates made to ./Juniper_Cloud_Native_Router_23.2/helmchart/values.yaml:
 1. Added nodeAffinity with key-value pair: key1=jcnr.
 2. Added fabricInterface: ens6.
 3. Changed restoreInterfaces to true.

NOTE: Make sure to set the 'cpu_core_mask' value in the values.yaml file as required for your setup.
Also, ensure that the added fabricInterface(s) are the ones you intend to use.
A backup of the original file has been saved to ./Juniper_Cloud_Native_Router_23.2/helmchart/values.yaml.bak.

Do you want to install JCNR with the auto-configured values.yaml file? (y/N): (You have 10 seconds to respond. Default is N): Y
Navigate to JCNR helm chart directory and helm install jcnr.
NAME: jcnr
LAST DEPLOYED: Sat Sep 16 00:06:39 2023
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
# sudo kubectl get nodes
NAME   STATUS   ROLES           AGE   VERSION
k1     Ready    control-plane   27m   v1.27.4
# 
# sudo kubectl get pods -A
NAMESPACE         NAME                                     READY   STATUS    RESTARTS   AGE
contrail-deploy   contrail-k8s-deployer-6b84fc9987-jmgzv   1/1     Running   0          25m
contrail          contrail-vrouter-masters-zmqzk           3/3     Running   0          25m
jcnr              kube-crpd-worker-sts-0                   1/1     Running   0          25m
jcnr              syslog-ng-rnw9s                          1/1     Running   0          25m
kube-system       coredns-5d78c9869d-sc2ht                 1/1     Running   0          27m
kube-system       etcd-k1                                  1/1     Running   0          27m
kube-system       kube-apiserver-k1                        1/1     Running   0          27m
kube-system       kube-controller-manager-k1               1/1     Running   0          27m
kube-system       kube-multus-ds-t4rqz                     1/1     Running   0          27m
kube-system       kube-proxy-qnt5b                         1/1     Running   0          27m
kube-system       kube-scheduler-k1                        1/1     Running   0          27m
kube-system       storage-provisioner                      1/1     Running   0          27m
# 
```