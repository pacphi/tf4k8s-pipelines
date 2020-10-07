# tf4k8s-pipelines

Sample GitOps pipelines that employ modules from tf4k8s to configure and deploy products and capabilities to targeted Kubernetes clusters

## Concourse

### Spin up a local instance

This script uses [Docker Compose](https://docs.docker.com/compose/install/) to launch a local [Concourse](https://concourse-ci.org/install.html) instance

```
./bin/launch-local-concourse-instance.sh
```

### Download CLI from Concourse instance

Download a version of the [fly](https://concourse-ci.org/fly.html) CLI from a known Concourse instance

```
wget https://<concourse_hostname>/api/v1/cli?arch=amd64&platform=<platform>
sudo mv fly /usr/local/bin
```
> Replace `concourse_hostname>` with the hostname of the Concourse instance you wish to target.  Also replace `<platform>` above with one of [ darwin, linux, windows].

### Login

```
fly login --target <target> --concourse-url https://<concourse_hostname> -u <username> -p <password>
```
> Replace `<target>` with any name (this acts as an alias for the connection details to the Concourse instance).  Also replace `concourse_hostname>` with the hostname of the Concourse instance you wish to target. Lastly, replace `<username>` and `<password>` with valid, authorized credentials to the Concourse instance team. 

### Build and push tf4k8s-toolsuite image

```
fly -t <target> set-pipeline -p build-and-push-tf4k8s-toolsuite-image \
    -c ./pipelines/build-and-push-tf4k8s-toolsuite-image.yml \
    --var image-repo-name=<repo-name> \
    --var registry-username=<user> \
    --var registry-password=<password>
```

* `<target>` is the alias for the connection details to a Concourse instance
* `<repo-name>` is a Container Image Repository prefix (e.g., harbor.envy.ironleg.me/library)
* `<username>` and `<password>` is the username of an account with read/write privileges to a Container Image Registry
