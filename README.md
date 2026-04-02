# Setup Assistant – README

## Overview

The Setup Assistant is a utility designed to perform system, network, Kubernetes, storage, and SQL pre-checks before deploying or troubleshooting clusters.  
It also supports debugging and sizing analysis to ensure cluster readiness.

\---

## Execution Flow

Run the main script:

./runcheck.sh

|Choice|Mode|Description|
|-|-|-|
|1|Baseline checks only|OS, Network, and Tools pre-checks.|
|2|Full checks only|Kubernetes, Registry, SQL, and Storage checks.|
|3|Debug pod only|Launches a debug pod for post-install troubleshooting.|
|4|Troubleshoot|K8s API and MTU checks to detect network or cluster issues.|
|5|Sizing checks|Cluster capacity, CPU, RAM, storage, and node sizing analysis.|

## FLOW DIAGRAM



&#x20;                ┌─────────────────────────────┐
                 │      runcheck.sh executed   │
                 └─────────────┬──────────────┘
                               │
                 ┌─────────────────────────────┐
                 │   Select Execution Mode     │
                 └─────────────┬──────────────┘
                               │
      ┌─────────┬─────────────┬─────────┬─────────┬─────────┐
      ▼         ▼             ▼         ▼         ▼

1. Baseline  2) Full       3) Debug   4) Troubleshoot 5) Sizing
(OS /       (K8s /        pod only   (K8s API +    (Cluster capacity \&
Network /   Registry /                MTU checks)   node sizing)
Tools)      SQL / Storage)







\## Cloning the Repository with Git LFS



This project uses \*\*Git Large File Storage (LFS)\*\* to manage Docker image archives (`.tar` files) that exceed GitHub's 100 MB limit.  

If you clone without LFS, the `.tar` files will appear as 1 KB pointer stubs instead of the full content.



\### Steps to Clone with LFS



1\. \*\*Install Git LFS\*\*

&#x20;  - Windows: Download from \[https://git-lfs.github.com/](https://git-lfs.github.com/) and run the installer

&#x20;  - macOS: `brew install git-lfs`

&#x20;  - Linux: `apt install git-lfs` or your package manager



2\. \*\*Initialize Git LFS\*\* (run once per system):

&#x20;  ```bash

&#x20;  git lfs install



3\. git clone https://github.com/HCL-TECH-SOFTWARE/Setup_Assistant.git

cd Setup\_Assistant

**
Post-Clone Notes**

Ensure the script has execute permission before running:
chmod +x runcheck.sh

If you encounter errors like /bin/sh^M: bad interpreter, it is due to Windows-style line endings. Convert the script to Unix format using:
dos2unix *.sh



