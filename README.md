# Setup Assistant – README

## Overview

The Setup Assistant is a utility designed to perform system, network, Kubernetes, storage, and SQL pre-checks before deploying or troubleshooting clusters.  
It also supports debugging and sizing analysis to ensure cluster readiness.

---

## Execution Flow

Run the main script:

./runcheck.sh

| Choice | Mode                 | Description                                                    |
| ------ | -------------------- | -------------------------------------------------------------- |
| 1      | Baseline checks only | OS, Network, and Tools pre-checks.                             |
| 2      | Full checks only     | Kubernetes, Registry, SQL, and Storage checks.                 |
| 3      | Debug pod only       | Launches a debug pod for post-install troubleshooting.         |
| 4      | Troubleshoot         | K8s API and MTU checks to detect network or cluster issues.    |
| 5      | Sizing checks        | Cluster capacity, CPU, RAM, storage, and node sizing analysis. |

## FLOW DIAGRAM


                 ┌─────────────────────────────┐
                 │      runcheck.sh executed   │
                 └─────────────┬──────────────┘
                               │
                 ┌─────────────────────────────┐
                 │   Select Execution Mode     │
                 └─────────────┬──────────────┘
                               │
      ┌─────────┬─────────────┬─────────┬─────────┬─────────┐
      ▼         ▼             ▼         ▼         ▼
1) Baseline  2) Full       3) Debug   4) Troubleshoot 5) Sizing
(OS /       (K8s /        pod only   (K8s API +    (Cluster capacity &
Network /   Registry /                MTU checks)   node sizing)
Tools)      SQL / Storage)
 
