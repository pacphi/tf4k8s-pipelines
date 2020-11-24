# tf4k8s-pipelines TAS4K8S Install

This script simplifies installing tas4k8s on [ AKS, EKS, GKE, and TKG (Azure and AWS only) ] taking full responsibility for provisioning cluster and installing necessary pre-requisites. 

## Preparation

You'll need a Concourse instance.

Make a copy of the config sample and fill it out for your own purposes with your own credentials.

```
cp one-click-tas4k8s-config.sh.sample one-click-tas4k8s-config.sh
```

## Execution

Make sure you're in the root directory and execute

```
./bin/tas4k8s/one-click-tas4k8s.sh
```
