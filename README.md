# JCNR-In-Server Setup Guide

This guide assists in setting up the DPDK app running environment for the Juniper Cloud-Native Router (JCNR). This setup focuses on a standalone JCNR in a server, perfect for demonstrations. It's crucial to understand that this setup is not for production use.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Overview

Our provided scripts ensure a smooth establishment of the required environment, including the Huge Page, VFIO/VFIO-PCI drivers, and essential kernel modules for cRPD.

After configuring everything, a system reboot is necessary to reflect the changes, especially in grub and hugepage size settings. The script will also install an All-in-One Kubernetes cluster via minikube. The Kubernetes node gets a label either from user input or a default, identifying it as the target for JCNR. This process will automatically install various tools like helm, kubectl, k9s, and more.

## Prerequisites

- Ubuntu server 22.04
- Downloaded JCNR package file

**Note:** Our installation scripts and steps are tailored for Ubuntu server 22.04.

## Configuration File (settings.sh)
Before starting the installation, you can optionally configure some of the setup parameters by updating the `settings.sh` file. Below are the available settings:

```bash
ONEG_HUGEPAGES=16              # Number of 1GB-sized hugepages
K8S_VERSION="latest"           # Kubernetes version, e.g., "v1.27.4" or "latest"
JCNR_LICENSE_KEY=""            # Raw license key
JCNR_ROOT_PASSWORD="jcnr123"   # Plain text root password
JCNR_LABEL="key1=jcnr"         # Key-value pair in "key=value" format
JCNR_FABRIC_INTERFACES=""      # Space-separated list of names, e.g., "ens5 ens6 ens7 ens8"
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/simonrho/jcnr-in-server.git
```
2. Move to the repository directory and execute the setup script with root permissions:
```bash
cd jcnr-in-server
sudo ./setup.sh
```

## Directory Structure

```
. 
├── setup.sh 
├── settings 
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

`setup.sh`: Kicks off the installation of the DPDK app environment, Kubernetes, and JCNR.
`install-dpdk-env.sh`: Sets up the DPDK app environment.
`install-k8s.sh`: Manages the All-in-One Kubernetes cluster installation.
`install-tools.sh`: Streamlines the installation of necessary tools like kubectl, helm, and k9s.
`create-jcnr-secrets.sh`: Creates the Kubernetes secrets manifest for JCNR licensing and the root password.
`create-label-update-values.sh`: Attaches a key/value label, marking it as the designated JCNR runner.
`load-jcnr-images.sh`: Inputs the JCNR container images into the local repository.  

## Licensing and JCNR Password

The script seeks the JCNR license key and root password in this sequence:


1. From the provided variables in the `settings.sh` file: `JCNR_LICENSE_KEY` and `JCNR_ROOT_PASSWORD`.
2. If the default `jcnr-license.txt` and `jcnr-root-password.txt` files are present in the directory.
3. If neither of the above sources are available, you will be prompted to manually input the JCNR root password and license key.


1. Through the settings.sh file variables: `JCNR_LICENSE_KEY` and `JCNR_ROOT_PASSWORD`.
2. Via default files `jcnr-license.txt` and `jcnr-root-password.txt` if found in the directory.
3. If neither are available, manual input of JCNR root password and license key is prompted.

The gathered details help in generating the `jcnr-secrets.yaml` file, subsequently applied to Kubernetes.


## JCNR-in-Server Setup Terminal Playback

[![asciicast](https://asciinema.org/a/xTH7eU7Uj8AbguYPHvzDPN2R6.svg)](https://asciinema.org/a/xTH7eU7Uj8AbguYPHvzDPN2R6?autoplay=1)

## Setup Output Sections

### 1. Preliminary Setup & System Restart

This section furnishes feedback on the setup concerning the DPDK environment preparation. This includes netplan configurations, Linux extra modules installation, cRPD module configurations, among others. After this stage, a system restart is advisable.

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
# sudo echo "<jcnr-license-key>" > jcnr-license.txt
#
# ls Juniper_Cloud_Native_Router*.tgz
Juniper_Cloud_Native_Router_23.2.tgz
#
sudo ./setup.sh 
./scripts/install-dpdk-env.sh: line 28: [: missing `]'

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
### 2. Kubernetes & JCNR Installations

Post-reboot, running the setup script progresses the Kubernetes cluster setup. This encompasses Docker, cri-dockerd, CNI plugins, and minikube installations. What follows is the JCNR installation, which entails loading JCNR images, creating Kubernetes secrets for JCNR, and updating the `values.yaml` file based on user choice or preset configurations.

```bash
sudo ./setup.sh 
This script has previously been executed and the system rebooted.

Running install-k8s.sh.
Logging install steps to install-k8s.log.
Installing Docker...
Installing cri-dockerd...
Installing crictl...
Installing CNI plugins...
Installing minikube... k8s version: latest
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
Extracting the file: Juniper_Cloud_Native_Router_23.2.tgz.
Found Docker image file: ./Juniper_Cloud_Native_Router_23.2/images/jcnr-images.tar.gz.
Loading Docker image..../Juniper_Cloud_Native_Router_23.2/images/jcnr-images.tar.gz.
Docker image loaded successfully!

Running create-jcnr-secrets.sh
This script will attempt to obtain the license key and root password in the following order:
1. From variables in the settings.sh file: JCNR_LICENSE_KEY and JCNR_ROOT_PASSWORD.
2. From the default files if present:
   License File: jcnr-license.txt
   Root Password File: jcnr-root-password.txt
3. If neither of the above sources are found, you will be prompted for input.
---------------------------------------
Reading root password from settings file.
Reading license key from jcnr-license.txt.
Creating jcnr-secrets.yaml file.
Applying JCNR secrets and namespace.
namespace/jcnr created
secret/jcnr-secrets created

Running create-label-update-values.sh.
Adding label key1=jcnr to the node k2.
node/k2 labeled
Updates made to ./Juniper_Cloud_Native_Router_23.2/helmchart/values.yaml:
 1. Added nodeAffinity with key-value pair: key1=jcnr.
 2. Added fabricInterface: ens6.
 3. Changed restoreInterfaces to true.

Note: Ensure you customize the 'cpu_core_mask' in the 'values.yaml' file to fit your setup.
And double-check that the added 'fabricInterface'(s) are your intended ones.
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