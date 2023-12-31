# JCNR-In-Server Setup Guide

This guide assists in setting up the DPDK app running environment for the Juniper Cloud-Native Router (JCNR). This setup focuses on a standalone JCNR in a server, perfect for demonstrations. It's crucial to understand that this setup is not for production use.

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**

- [Overview](#overview)
- [Prerequisites](#prerequisites)
- [Tested JCNR Versions](#tested-jcnr-versions)
- [Configuration File](#configuration-file)
- [Installation](#installation)
- [Directory Structure](#directory-structure)
- [File Descriptions](#file-descriptions)
- [Licensing and JCNR Password](#licensing-and-jcnr-password)
- [Loading JCNR container images](#loading-jcnr-container-images)
- [JCNR-in-Server Setup Terminal Playback](#jcnr-in-server-setup-terminal-playback)
- [Setup Output Sections](#setup-output-sections)
  - [1. Preliminary Setup & System Restart](#1-preliminary-setup--system-restart)
  - [2. Kubernetes & JCNR Installations](#2-kubernetes--jcnr-installations)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Overview

Our provided scripts ensure a smooth establishment of the required environment, including the Huge Page, VFIO/VFIO-PCI drivers, and essential kernel modules for cRPD.

After configuring everything, a system reboot is necessary to reflect the changes, especially in grub and hugepage size settings. The script will also install an All-in-One Kubernetes cluster via minikube. The Kubernetes node gets a label either from user input or a default, identifying it as the target for JCNR. This process will automatically install various tools like helm, kubectl, k9s, and more.

## Prerequisites

- Ubuntu server (22.04, 20.04, or 18.04)
- Downloaded JCNR package file

**Note:** Our installation scripts and steps are primarily tailored for Ubuntu server 22.04. However, they have also been tested on Ubuntu 20.04 and 18.04.

## Tested JCNR Versions
Our jcnr server installation has been successfully tested and is compatible with the following JCNR versions:

- JCNR 23.2 
  - File: Juniper_Cloud_Native_Router_23.2.tgz
- JCNR 23.3 
  - File: Juniper_Cloud_Native_Router_23.3-183.tar.gz

This list will be updated as more versions are validated.


## Configuration File
Before starting the installation, you can optionally configure some of the setup parameters by updating the `settings` file. Below are the available settings:

```bash
ONEG_HUGEPAGES=16                       # Number of 1GB-sized hugepages
ISOLATED_CPUS="auto"                    # Can be "", "auto", or a valid CPU range (e.g., "1-4,6").
                                        # If the value is "": 'isolcpus' won't be added to GRUB_CMDLINE_LINUX_DEFAULT in grub.
                                        # If the value is "auto": For a single NUMA, the 1st half of the CPUs will be isolated. 
                                        # For multiple NUMA configurations, all CPUs of the 1st node will be isolated.
                                        # If the total CPU count is 4 or fewer, no CPUs will be isolated.
K8S_VERSION="latest"                    # Kubernetes version, e.g., "v1.27.4" or "latest"
K8S_CNI="calico"                        # Kubernetes CNI, e.g., "bridge" "flannel", "calico"
JCNR_LICENSE_KEY=""                     # Raw license key, e.g., "JUNOS892191212 aeaq...."
JCNR_ROOT_PASSWORD="jcnr123"            # Plain text root password, e.g., "jcnr123"
JCNR_LABEL="key1=jcnr"                  # Key-value pair in "key=value" format
JCNR_FABRIC_INTERFACES=""               # Space-separated list of names, e.g., "ens5 ens6 ens7 ens8"
JCNR_MTU="9000"                         # MTU for all physical interfaces( all VF’s and  PF’s)
JCNR_CPU_CORE_MASK="2,3,22,23"          # Vrouter fwd core mask. Comma-separated list.
JCNR_VROUTER_DPDK_UIO_DRIVER="vfio-pci" # uio driver will be "vfio-pci" or "uio_pci_generic"
JCNR_RESTORE_INTERFACES="true"          # Restore the interface original state. "true" or "false"
JCNR_VROUTER_RESOURCE_MEMORY="default"  # Set the maximum memory limit & the initial memory request - e.g., "default", "6Gi"
                                        # Keep the default value; this is only for low-memory server cases
```

## Installation

1. Clone the repository:
```bash
git clone https://github.com/simonrho/jcnr-in-server.git
```

2. Copy the JCNR package file to the setup directory using:
```bash
cp ./Juniper_Cloud_Native_Router_23.2.tgz ./jcnr-in-server/ubuntu/
```

3. Update the settings file:
```bash
cd jcnr-in-server/ubuntu
cat ./settings
ONEG_HUGEPAGES=16                       # Number of 1GB-sized hugepages
ISOLATED_CPUS="auto"                    # Can be "", "auto", or a valid CPU range (e.g., "1-4,6").
                                        # If the value is "": 'isolcpus' won't be added to GRUB_CMDLINE_LINUX_DEFAULT in grub.
                                        # If the value is "auto": For a single NUMA, the 1st half of the CPUs will be isolated. 
                                        # For multiple NUMA configurations, all CPUs of the 1st node will be isolated.
                                        # If the total CPU count is 4 or fewer, no CPUs will be isolated.
K8S_VERSION="latest"                    # Kubernetes version, e.g., "v1.27.4" or "latest"
K8S_CNI="calico"                        # Kubernetes CNI, e.g., "bridge" "flannel", "calico"
JCNR_LICENSE_KEY=""                     # Raw license key, e.g., "JUNOS892191212 aeaq...."
JCNR_ROOT_PASSWORD="jcnr123"            # Plain text root password, e.g., "jcnr123"
JCNR_LABEL="key1=jcnr"                  # Key-value pair in "key=value" format
JCNR_FABRIC_INTERFACES=""               # Space-separated list of names, e.g., "ens5 ens6 ens7 ens8"
JCNR_MTU="9000"                         # MTU for all physical interfaces( all VF’s and  PF’s)
JCNR_CPU_CORE_MASK="2,3,22,23"          # Vrouter fwd core mask. Comma-separated list.
JCNR_VROUTER_DPDK_UIO_DRIVER="vfio-pci" # uio driver will be "vfio-pci" or "uio_pci_generic"
JCNR_RESTORE_INTERFACES="true"          # Restore the interface original state. "true" or "false"
JCNR_VROUTER_RESOURCE_MEMORY="default"  # Set the maximum memory limit & the initial memory request - e.g., "default", "6Gi"
                                        # Keep the default value; this is only for low-memory server cases

```

4. Move to the repository directory and execute the setup script with root permissions:
```bash
sudo ./setup.sh
```

## Directory Structure

```
. 
└── jcnr-in-server 
    ├── ubuntu
        ├── setup.sh 
        ├── settings 
        └── scripts 
            ├── create-jcnr-secrets.sh 
            ├── create-label-update-values.sh 
            ├── install-dpdk-env.sh 
            ├── install-k8s.sh 
            ├── install-tools.sh 
            └── load-jcnr-images.sh 
```

## File Descriptions

- `setup.sh`: Kicks off the installation of the DPDK app environment, Kubernetes, and JCNR.
- `install-dpdk-env.sh`: Sets up the DPDK app environment.
- `install-k8s.sh`: Manages the All-in-One Kubernetes cluster installation.
- `install-tools.sh`: Streamlines the installation of necessary tools like kubectl, helm, and k9s.
- `create-jcnr-secrets.sh`: Creates the Kubernetes secrets manifest for JCNR licensing and the root password.
- `create-label-update-values.sh`: Attaches a key/value label, marking it as the designated JCNR runner.
- `load-jcnr-images.sh`: Inputs the JCNR container images into the local repository.  

## Licensing and JCNR Password

The script seeks the JCNR license key and root password in this sequence:


1. From the provided variables in the `settings` file: `JCNR_LICENSE_KEY` and `JCNR_ROOT_PASSWORD`.
2. If the default `jcnr-license.txt` and `jcnr-root-password.txt` files are present in the directory.
3. If neither of the above sources are available, you will be prompted to manually input the JCNR root password and license key.

The gathered details help in generating the `jcnr-secrets.yaml` file, subsequently applied to Kubernetes.

## Loading JCNR container images
Please ensure that the JCNR package .tgz, downloaded from the Juniper Networks support site (containing JCNR container images and helm charts), is copied into the directory where the setup.sh script resides.

## JCNR-in-Server Setup Terminal Playback

[![asciicast](https://asciinema.org/a/vbY7fFvtYeaaM5y3lnm2dCiOx.svg)](https://asciinema.org/a/vbY7fFvtYeaaM5y3lnm2dCiOx?autoplay=1)

## Setup Output Sections

### 1. Preliminary Setup & System Restart

This section furnishes feedback on the setup concerning the DPDK environment preparation. This includes netplan configurations, Linux extra modules installation, cRPD module configurations, among others. After this stage, a system restart is advisable.

```bash
~$ ls
Juniper_Cloud_Native_Router_23.2.tgz  jcnr-license.txt
~$
~$ git clone https://github.com/simonrho/jcnr-in-server.git
Cloning into 'jcnr-in-server'...
remote: Enumerating objects: 124, done.
remote: Counting objects: 100% (7/7), done.
remote: Compressing objects: 100% (6/6), done.
remote: Total 124 (delta 1), reused 7 (delta 1), pack-reused 117
Receiving objects: 100% (124/124), 30.47 KiB | 3.81 MiB/s, done.
Resolving deltas: 100% (62/62), done.
~$
~$
~$
~$ tree
.
├── Juniper_Cloud_Native_Router_23.2.tgz
├── jcnr-in-server
│   ├── LICENSE.txt
│   ├── README.md
│   └── ubuntu
│       ├── scripts
│       │   ├── create-jcnr-secrets.sh
│       │   ├── create-label-update-values.sh
│       │   ├── install-dpdk-env.sh
│       │   ├── install-k8s.sh
│       │   ├── install-tools.sh
│       │   └── load-jcnr-images.sh
│       ├── settings
│       └── setup.sh
└── jcnr-license.txt

3 directories, 12 files
~$
~$
~$ cd jcnr-in-server/ubuntu/
~/jcnr-in-server/ubuntu$ cp ~/Juniper_Cloud_Native_Router_23.2.tgz .
~/jcnr-in-server/ubuntu$ cp ~/jcnr-license.txt .
~/jcnr-in-server/ubuntu$
~/jcnr-in-server/ubuntu$
~/jcnr-in-server/ubuntu$ cat settings
ONEG_HUGEPAGES=16                       # Number of 1GB-sized hugepages
ISOLATED_CPUS="auto"                    # Can be "", "auto", or a valid CPU range (e.g., "1-4,6").
                                        # If the value is "": 'isolcpus' won't be added to GRUB_CMDLINE_LINUX_DEFAULT in grub.
                                        # If the value is "auto": For a single NUMA, the 1st half of the CPUs will be isolated. 
                                        # For multiple NUMA configurations, all CPUs of the 1st node will be isolated.
                                        # If the total CPU count is 4 or fewer, no CPUs will be isolated.
K8S_VERSION="latest"                    # Kubernetes version, e.g., "v1.27.4" or "latest"
K8S_CNI="calico"                        # Kubernetes CNI, e.g., "bridge" "flannel", "calico"
JCNR_LICENSE_KEY=""                     # Raw license key, e.g., "JUNOS892191212 aeaq...."
JCNR_ROOT_PASSWORD="jcnr123"            # Plain text root password, e.g., "jcnr123"
JCNR_LABEL="key1=jcnr"                  # Key-value pair in "key=value" format
JCNR_FABRIC_INTERFACES=""               # Space-separated list of names, e.g., "ens5 ens6 ens7 ens8"
JCNR_MTU="9000"                         # MTU for all physical interfaces( all VF’s and  PF’s)
JCNR_CPU_CORE_MASK="2,3,22,23"          # Vrouter fwd core mask. Comma-separated list.
JCNR_VROUTER_DPDK_UIO_DRIVER="vfio-pci" # uio driver will be "vfio-pci" or "uio_pci_generic"
JCNR_RESTORE_INTERFACES="true"          # Restore the interface original state. "true" or "false"
JCNR_VROUTER_RESOURCE_MEMORY="default"  # Set the maximum memory limit & the initial memory request - e.g., "default", "6Gi"
                                        # Keep the default value; this is only for low-memory server cases

~/jcnr-in-server/ubuntu$
~/jcnr-in-server/ubuntu$
~/jcnr-in-server/ubuntu$ vi settings
~/jcnr-in-server/ubuntu$
~/jcnr-in-server/ubuntu$ cat settings
ONEG_HUGEPAGES=16                       # Number of 1GB-sized hugepages
ISOLATED_CPUS="auto"                    # Can be "", "auto", or a valid CPU range (e.g., "1-4,6").
                                        # If the value is "": 'isolcpus' won't be added to GRUB_CMDLINE_LINUX_DEFAULT in grub.
                                        # If the value is "auto": For a single NUMA, the 1st half of the CPUs will be isolated. 
                                        # For multiple NUMA configurations, all CPUs of the 1st node will be isolated.
                                        # If the total CPU count is 4 or fewer, no CPUs will be isolated.
K8S_VERSION="latest"                    # Kubernetes version, e.g., "v1.27.4" or "latest"
K8S_CNI="calico"                        # Kubernetes CNI, e.g., "bridge" "flannel", "calico"
JCNR_LICENSE_KEY=""                     # Raw license key, e.g., "JUNOS892191212 aeaq...."
JCNR_ROOT_PASSWORD="jcnr123"            # Plain text root password, e.g., "jcnr123"
JCNR_LABEL="key1=jcnr"                  # Key-value pair in "key=value" format
JCNR_FABRIC_INTERFACES="ens6"               # Space-separated list of names, e.g., "ens5 ens6 ens7 ens8"
JCNR_MTU="9000"                         # MTU for all physical interfaces( all VF’s and  PF’s)
JCNR_CPU_CORE_MASK="2,3,22,23"          # Vrouter fwd core mask. Comma-separated list.
JCNR_VROUTER_DPDK_UIO_DRIVER="vfio-pci" # uio driver will be "vfio-pci" or "uio_pci_generic"
JCNR_RESTORE_INTERFACES="true"          # Restore the interface original state. "true" or "false"
JCNR_VROUTER_RESOURCE_MEMORY="default"  # Set the maximum memory limit & the initial memory request - e.g., "default", "6Gi"
                                        # Keep the default value; this is only for low-memory server cases


~/jcnr-in-server/ubuntu$
~/jcnr-in-server/ubuntu$ ./setup.sh
This script must be run as root.

~/jcnr-in-server/ubuntu$ sudo ./setup.sh

Running install-dpdk-env.sh.
Logging install steps to install-dpdk-env.log.
Netplan configuration done.
Installing Linux extra modules. It might take a few minutes. Please be patient.
Linux extra modules installed.
cRPD related modules configuration done.
VFIO modules configuration done.
VFIO extra option setup done.
THP disabled.
bridge and br_netfilter module setup complete.
iptables setup for internet access from the pods is complete.
Huge Pages setup complete.
Isoclated cpu range is 0,1,2,3,4,5,6,7
1G HugePages count: 16
grub file updated: /etc/default/grub.d/50-cloudimg-settings.cfg
GRUB updated.
Installation completed. Check install-dpdk-env.log for detailed logs.
Please ensure the IOMMU is enabled in the BIOS/UEFI.
Reboot now? (y/N): (You have 30 seconds to respond. Default is Y): Y
```

### 2. Kubernetes & JCNR Installations

Post-reboot, running the setup script progresses the Kubernetes cluster setup. This encompasses Docker, cri-dockerd, CNI plugins, and minikube installations. What follows is the JCNR installation, which entails loading JCNR images, creating Kubernetes secrets for JCNR, and updating the `values.yaml` file based on user choice or preset configurations.

```bash
$ cd jcnr-in-server/ubuntu/
~/jcnr-in-server/ubuntu$ ls
Juniper_Cloud_Native_Router_23.2.tgz  install-dpdk-env.log  jcnr-license.txt  scripts  settings  setup.sh
~/jcnr-in-server/ubuntu$ 
~/jcnr-in-server/ubuntu$ 
~/jcnr-in-server/ubuntu$ sudo ./setup.sh 
This script has previously been executed and the system rebooted.

Running install-k8s.sh.
Logging install steps to install-k8s.log.
Installing Docker...
Installing cri-dockerd...
Installing crictl...
Installing CNI plugins...
Installing minikube...
Installed k8s version: v1.28.0-rc.1
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
Loading Docker image: ./Juniper_Cloud_Native_Router_23.2/images/jcnr-images.tar.gz.
Docker image loaded successfully!

Running create-jcnr-secrets.sh
This script will attempt to obtain the license key and root password in the following order:
1. From variables in the settings file: JCNR_LICENSE_KEY and JCNR_ROOT_PASSWORD.
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
Adding label key1=jcnr to the node k1.
node/k1 labeled
Updates made to ./Juniper_Cloud_Native_Router_23.2/helmchart/values.yaml:
 1. Added nodeAffinity with key-value pair: key1=jcnr.
 2. Added fabricInterface: ens6.
 3. Updated mtu to 9000.
 4. Updated restoreInterfaces to true.
 5. Updated cpu_core_mask to 2,3,22,23.
 6. Updated vrouter_dpdk_uio_driver to vfio-pci.

Note: Please double-check that the 'fabricInterface' entries and other configurations in the 'values.yaml' file match your intentions.
A backup of the original file is saved as ./Juniper_Cloud_Native_Router_23.2/helmchart/values.yaml.bak.

Do you want to install JCNR with the auto-configured values.yaml file? (y/N): (You have 30 seconds to respond. Default is N): Y
Navigate to JCNR helm chart directory and helm install jcnr.
NAME: jcnr
LAST DEPLOYED: Tue Sep 19 20:01:21 2023
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
~/jcnr-in-server/ubuntu$ sudo kubectl get pods -A
NAMESPACE         NAME                                       READY   STATUS    RESTARTS      AGE
contrail-deploy   contrail-k8s-deployer-84b699fcdc-z6l7m     1/1     Running   0             5m36s
contrail          contrail-vrouter-masters-wll5x             3/3     Running   0             5m28s
jcnr              kube-crpd-worker-sts-0                     1/1     Running   0             5m36s
jcnr              syslog-ng-jthgk                            1/1     Running   0             5m36s
kube-system       calico-kube-controllers-7ddc4f45bc-6btwp   1/1     Running   0             25m
kube-system       calico-node-6wkvr                          1/1     Running   0             25m
kube-system       coredns-5dd5756b68-n4bmk                   1/1     Running   0             25m
kube-system       etcd-k1                                    1/1     Running   0             26m
kube-system       kube-apiserver-k1                          1/1     Running   0             26m
kube-system       kube-controller-manager-k1                 1/1     Running   0             26m
kube-system       kube-multus-ds-68ft4                       1/1     Running   2 (24m ago)   25m
kube-system       kube-proxy-kj9rh                           1/1     Running   0             25m
kube-system       kube-scheduler-k1                          1/1     Running   0             26m
kube-system       storage-provisioner                        1/1     Running   0             26m
~/jcnr-in-server/ubuntu$ 
```