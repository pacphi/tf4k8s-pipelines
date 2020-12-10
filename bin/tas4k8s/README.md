# tf4k8s-pipelines - tas4k8s install

This script simplifies installing tas4k8s on [ AKS, EKS, GKE, and TKG (Azure and AWS only) ] taking full responsibility for provisioning cluster and installing necessary pre-requisites.  Harbor is the currently integrated container image registry provider.

## Preparation

You'll need a Concourse instance and the fly CLI.

Configure [rclone](https://rclone.org/commands/rclone_config/) to interact with a chosen cloud provider's storage API.

Make a copy of the config sample and fill it out for your own purposes with your own credentials.

```
cp one-click-tas4k8s-config.sh.sample one-click-tas4k8s-config.sh
```

## Execution

Make sure you're in the root directory and execute

```
./bin/tas4k8s/one-click-tas4k8s-install.sh
```
