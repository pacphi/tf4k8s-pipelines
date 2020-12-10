# tf4k8s-pipelines - build and publish container images

This script simplifies creating Concourse pipelines for building and publishing the collection of container images that power tf4k8s-pipelines to Dockerhub.

## Preparation

You'll need a Concourse instance and the fly CLI.

Make a copy of the config sample and fill it out for your own purposes with your own credentials.

```
cp one-click-images-config.sh.sample one-click-images-config.sh
```

## Execution

Make sure you're in the root directory and execute

```
./bin/images/one-click-images-install.sh
```
