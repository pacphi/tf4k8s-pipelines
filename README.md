# tf4k8s-pipelines

Sample GitOps pipelines that employ modules from [tf4k8s](https://github.com/pacphi/tf4k8s) to configure and deploy products and capabilities to targeted Kubernetes clusters.

## Concourse

![Concourse pipelines screenshot](concourse-pipelines.png?raw=true "Concourse pipelines screenshot")
![Install TAS4K8s pipeline screenshot](install-tas4k8s.png?raw=true "Install TAS4K8s pipeline screenshot")

You could spin up a local [Concourse](https://concourse-ci.org/install.html) instance for test purposes. Or you might consider employing the [control-tower](https://github.com/EngineerBetter/control-tower) CLI to deploy a self-healing, self-updating Concourse instance with [Grafana](https://grafana.com/) and [CredHub](https://docs.cloudfoundry.org/credhub/) in either AWS or GCP.

### Getting Started

#### Deploying a local instance

<details><summary>Start</summary><pre>./bin/launch-local-concourse-instance.sh</pre></details>

> This script uses [Docker Compose](https://docs.docker.com/compose/install/) to launch a local Concourse instance

<details><summary>Change directories</summary><pre>cd .concourse-local</pre></details> 

> to lifecycle manage the instance 

<details><summary>Stop</summary><pre>docker-compose stop</pre></details>

<details><summary>Restart</summary><pre>docker-compose restart -d</pre></details>

<details><summary>Teardown</summary><pre>docker-compose down</pre></details>

#### Deploying a cloud-hosted instance

Consult the control-tower CLI install [documentation](https://github.com/EngineerBetter/control-tower#tldr).

### Install the fly CLI

Download a version of the [fly](https://concourse-ci.org/fly.html) CLI from the Concourse instance you just deployed.

```
wget https://<concourse_hostname>/api/v1/cli?arch=amd64&platform=<platform>
sudo mv fly /usr/local/bin
```
> Replace `concourse_hostname>` with the hostname of the Concourse instance you wish to target.  Also replace `<platform>` above with one of [ darwin, linux, windows].

### Login to a Concourse instance with the fly CLI

```
fly login --target <target> --concourse-url https://<concourse_hostname> -u <username> -p <password>
```
> Replace `<target>` with any name (this acts as an alias for the connection details to the Concourse instance).  Also replace `concourse_hostname>` with the hostname of the Concourse instance you wish to target. Lastly, replace `<username>` and `<password>` with valid, authorized credentials to the Concourse instance team. 

### Build and push the terraform-resource-with-az-cli image

A Concourse resource based off [ljfranklin/terraform-resource](https://github.com/ljfranklin/terraform-resource#terraform-concourse-resource) that also includes the Azure [CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
```
fly -t <target> set-pipeline -p build-and-push-terraform-resource-with-az-cli-image \
    -c ./pipelines/build-and-push-terraform-resource-with-az-cli-image.yml \
    --var image-repo-name=<repo-name> \
    --var registry-username=<user> \
    --var registry-password=<password>
fly -t <target> unpause-pipeline -p build-and-push-terraform-resource-with-az-cli-image
```

* `<target>` is the alias for the connection details to a Concourse instance
* `<repo-name>` is a container image repository prefix (e.g., docker.io or a private registry like harbor.envy.ironleg.me/library)
* `<username>` and `<password>` are the credentials of an account with read/write privileges to a container image registry

> A pre-built container image exists on DockerHub, here: [pacphi/terraform-resource-with-az-cli](https://hub.docker.com/repository/docker/pacphi/terraform-resource-with-az-cli).

### Build and push the terraform-resource-with-carvel image

A Concourse resource based off [ljfranklin/terraform-resource](https://github.com/ljfranklin/terraform-resource#terraform-concourse-resource) that also includes the Terraform [Carvel](https://carvel.dev/) [plugin](https://github.com/k14s/terraform-provider-k14s/blob/develop/docs/README.md).

```
fly -t <target> set-pipeline -p build-and-push-terraform-resource-with-carvel-image \
    -c ./pipelines/build-and-push-terraform-resource-with-carvel-image.yml \
    --var image-repo-name=<repo-name> \
    --var registry-username=<user> \
    --var registry-password=<password>
fly -t <target> unpause-pipeline -p build-and-push-terraform-resource-with-carvel-image
```

* `<target>` is the alias for the connection details to a Concourse instance
* `<repo-name>` is a container image repository prefix (e.g., docker.io or a private registry like harbor.envy.ironleg.me/library)
* `<username>` and `<password>` are the credentials of an account with read/write privileges to a container image registry

> A pre-built container image exists on DockerHub, here: [pacphi/terraform-resource-with-carvel](https://hub.docker.com/repository/docker/pacphi/terraform-resource-with-carvel).

### Build and push the bby image

A simple image based on [alpine](https://alpinelinux.org/about/) that includes [bash](https://www.gnu.org/software/bash/), [bosh](https://bosh.io/docs/cli-v2/) and [ytt](https://get-ytt.io/).

```
fly -t <target> set-pipeline -p build-and-push-bby-image \
    -c ./pipelines/build-and-push-bash-bosh-and-ytt-image.yml \
    --var image-repo-name=<repo-name> \
    --var registry-username=<user> \
    --var registry-password=<password>
fly -t <target> unpause-pipeline -p build-and-push-bby-image
```

* `<target>` is the alias for the connection details to a Concourse instance
* `<repo-name>` is a container image repository prefix (e.g., docker.io or a private registry like harbor.envy.ironleg.me/library)
* `<username>` and `<password>` are the credentials of an account with read/write privileges to a container image registry

> A pre-built container image exists on DockerHub, here: [pacphi/bby](https://hub.docker.com/repository/docker/pacphi/bby).

### Build and push the terraform-resource-with-tkg-tmc image

A Concourse resource based off [ljfranklin/terraform-resource](https://github.com/ljfranklin/terraform-resource#terraform-concourse-resource) that also includes these command-line interfaces: tkg, tkgi and tmc.

```
fly -t <target> set-pipeline -p build-and-push-terraform-resource-with-tkg-tmc-image \
    -c ./pipelines/build-and-push-terraform-resource-with-tkg-tmc-image.yml \
    --var image-repo-name=<repo-name> \
    --var registry-username=<user> \
    --var registry-password=<password> \
    --var vmw_username=<vmw_username> \
    --var vmw_password=<vmw_password> \
fly -t <target> unpause-pipeline -p terraform-resource-with-tkg-tmc-image
```

* `<target>` is the alias for the connection details to a Concourse instance
* `<repo-name>` is a container image repository prefix (e.g., docker.io or a private registry like harbor.envy.ironleg.me/library)
* `<username>` and `<password>` are the credentials of an account with read/write privileges to a container image registry
* `<vmw_username>` and `<vmw_password>` are the credentials of an account on my.vmwware.com

> This image contains commercially licensed software - you'll need to build it yourself and publish in a private container image registry

### tf4k8s-pipelines: A Guided Tour

#### Setup 

Create a mirrored directory structure as found underneath [tf4k8s/experiments](https://github.com/pacphi/tf4k8s/tree/master/experiments).

You'll want to abide by some convention if you're going to manage multiple environments. Create a subdirectory for each environment you wish to manage.  Then mirror the experiments subdirectory structure under each environment directory.

For example:

```
+ tf4k8s-pipelines-config
  + n00b
    + gcp
      + certmanager
      + cluster
      + dns
      + external-dns
    + k8s
      + nginx-ingress-controller
      + harbor
      + tas4k8s
```

Place a `terraform.tfvars` file in each of the leaf subdirectories you wish to drive a `terraform` `plan` or `apply`.

For example:

```
+ tf4k8s-pipelines-config
  + n00b
    + gcp
      + dns
        - terraform.tfvars
```

Here's a sample of the above module's file's contents:

**terraform.tfvars**

```
project = "fe-cphillipson"
gcp_service_account_credentials = "/tmp/build/put/credentials/gcp-credentials.json"
root_zone_name = "ironleg-zone"
environment_name = "n00b"
dns_prefix = "n00b"
```

Now we'll want to maintain secrets like a) cloud credentials and b) `./kube/config`.  The following is an example structure when working with Google Cloud Platform and an environment named `n00b`.

```
+ s3cr3ts
  + n00b
    + .kube
      - config
    - gcp-credentials.json
```

Lastly we'll want to maintain state for each Terraform module.  We won't need a local directory, but we can use `rclone` to create a bucket.

Use [rclone](https://rclone.org/) to synchronize your local configuration (and in some instances credentials) with a cloud storage provider of your choice.

Execute `rclone config` to configure a target storage provider.

You could create a bucket with `rclone mkdir <target>:<bucket_name>`.

And you could sync with `rclone sync -i /path/to/config <target>:<bucket_name>`

For example, when working with Google Cloud Storage (GCS)...

```
rclone mkdir fe-cphillipson-gcs:s3cr3ts
rclone sync -i /home/cphillipson/Documents/development/pivotal/tanzu/s3cr3ts fe-cphillipson-gcs:s3cr3ts
rclone mkdir fe-cphillipson-gcs:tf4k8s-pipelines-config
rclone sync -i /home/cphillipson/Documents/development/pivotal/tanzu/tf4k8s-pipelines-config fe-cphillipson-gcs:tf4k8s-pipelines-config
rclone mkdir fe-cphillipson-gcs:tf4k8s-pipelines-state
rclone mkdir fe-cphillipson-gcs:tas4k8s-bundles

gsutil versioning set on gs://s3cr3ts
gsutil versioning set on gs://tf4k8s-pipelines-config
gsutil versioning set on gs://tf4k8s-pipelines-state
gsutil versioning set on gs://tas4k8s-bundles
```
> * When working with GCS you must enable versioning on each bucket

#### Pipeline definitions, Terraform and configuration

We'll continue to use the fly CLI to upload pipeline definitions with configuration (in this case we're talking about Concourse YAML [configuration](https://concourse-ci.org/config-basics.html#basic-schemas)).

All pipeline definitions in this repository are found in the [pipelines](https://github.com/pacphi/tf4k8s-pipelines/tree/main/pipelines) directory.  As mentioned each pipeline is the realization of a definition and configuration (i.e., any value encapsulated in `(())` or `{{}}`), so inspect the yaml for each definition to see what's expected.

Terraform modules are found in the [terraform](https://github.com/pacphi/tf4k8s-pipelines/tree/main/terraform) directory.

For convenience we'll want to create a `ci` sub-directory to collect all our configuration. And for practical purposes we'll want to create a subdirectory structure that mirrors what we created earlier, so something like:

```
+ tf4k8s-pipelines
  + ci
    + n00b
      + gcp
        - create-dns.yml
        - create-cluster.yml
        - install-certmanager.yml
        - install-nginx-ingress-controller.yml
        - install-external-dns.yml
        - install-harbor.yml
        - install-tas4k8s.yml
```

Are you wondering about the content of those files?  Here are a couple examples:

**create-dns.yml**

```
terraform_module: gcp/dns
pipeline_repo_branch: main
environment_name: n00b
gcp_storage_bucket_folder: gcp/dns
gcp_account_key_json: |
  {
    "type": "service_account",
    "project_id": "REPLACE_ME",
    "private_key_id": "REPLACE_ME",
    "private_key": "-----BEGIN PRIVATE KEY-----\nREPLACE_ME\n-----END PRIVATE KEY-----\n",
    "client_email": "REPLACE_ME.iam.gserviceaccount.com",
    "client_id": "REPLACE_ME",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://accounts.google.com/o/oauth2/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/REPLACE_ME.iam.gserviceaccount.com"
  }
```

**install-harbor.yml**

```
terraform_resource_with_carvel_image: pacphi/terraform-resource-with-carvel
registry_username: REPLACE_ME
registry_password: REPLACE_ME
terraform_module: k8s/harbor
pipeline_repo_branch: main
environment_name: n00b
gcp_storage_bucket_folder: k8s/harbor
gcp_account_key_json: |
  {
    "type": "service_account",
    "project_id": "REPLACE_ME",
    "private_key_id": "REPLACE_ME",
    "private_key": "-----BEGIN PRIVATE KEY-----\nREPLACE_ME\n-----END PRIVATE KEY-----\n",
    "client_email": "REPLACE_ME.iam.gserviceaccount.com",
    "client_id": "REPLACE_ME",
    "auth_uri": "https://accounts.google.com/o/oauth2/auth",
    "token_uri": "https://accounts.google.com/o/oauth2/token",
    "auth_provider_x509_cert_url": "https://www.googleapis.com/oauth2/v1/certs",
    "client_x509_cert_url": "https://www.googleapis.com/robot/v1/metadata/x509/REPLACE_ME.iam.gserviceaccount.com"
  }

```

So putting this into practice, if we wanted to create a new Cloud DNS zone in Google Cloud, we could execute 

```
fly -t <target> set-pipeline -p create-dns -c ./pipelines/gcp/terraformer.yml -l ./ci/n00b/gcp/create-dns.yml
fly -t <target> unpause-pipeline -p create-dns
```

And other pipelines you might execute (in order) to install a TAS 3.0 instance atop a GKE cluster

```
fly -t <target> set-pipeline -p create-cluster -c ./pipelines/gcp/terraformer.yml -l ./ci/n00b/gcp/create-cluster.yml
fly -t <target> unpause-pipeline -p create-cluster

fly -t <target> set-pipeline -p install-certmanager -c ./pipelines/gcp/terraformer-with-carvel.yml -l ./ci/n00b/gcp/install-certmanager.yml
fly -t <target> unpause-pipeline -p install-certmanager
fly -t <target> set-pipeline -p install-nginx-ingress-controller -c ./pipelines/gcp/terraformer-with-carvel.yml -l ./ci/n00b/gcp/install-nginx-ingress-controller.yml
fly -t <target> unpause-pipeline -p install-nginx-ingress-controller
fly -t <target> set-pipeline -p install-external-dns -c ./pipelines/gcp/terraformer-with-carvel.yml -l ./ci/n00b/gcp/install-external-dns.yml
fly -t <target> unpause-pipeline -p install-external-dns
fly -t <target> set-pipeline -p install-harbor -c ./pipelines/gcp/terraformer-with-carvel.yml -l ./ci/n00b/gcp/install-harbor.yml
fly -t <target> unpause-pipeline -p install-harbor

fly -t <target> set-pipeline -p install-tas4k8s -c ./pipelines/gcp/tas4k8s.yml -l ./ci/n00b/gcp/install-tas4k8s.yml
fly -t <target> unpause-pipeline -p install-tas4k8s
```

Admittedly this is a bit of effort to assemble.  To help get you started, visit the [dist/concourse](https://github.com/pacphi/tf4k8s-pipelines/tree/main/dist/concourse) folder, download and unpack the sample environment template(s). Make sure to update all occurrences of `REPLACE_ME` within the configuration files. 

#### Workflow Summary

* All buckets must have versioning enabled!
  * Consult the target provider's documentation for how to do this for each bucket created. (e.g., [Amazon S3](https://docs.aws.amazon.com/AmazonS3/latest/user-guide/enable-versioning.html), [Azure Blob Storage](https://docs.microsoft.com/en-us/azure/storage/blobs/versioning-enable?tabs=portal), [Google Cloud Storage](https://cloud.google.com/storage/docs/gsutil/addlhelp/ObjectVersioningandConcurrencyControl))
* Store secrets like your cloud provider credentials or `./kube/config` (in file format) in a storage bucket.
* Remember to synchronize your local copy of `t4k8s-pipelines-config` when an addition or update is made to one or more `terraform.tfvars` files.
  * Use `rclone sync` with caution. If you don't want to destroy previous state, use `rclone copy` instead.
* Remember that you have to `git commit` and `git push` updates to the `tf4k8s-pipelines` git repository any time you make additions/updates to contents under a) `pipelines` or b) `terraform` directory trees before executing `fly set-pipeline`.
* Remember to execute `fly set-pipeline` any time you a) adapt a pipeline definition or b) edit Concourse configuration
* When using Concourse [terraform-resource](https://github.com/ljfranklin/terraform-resource), if you choose to include a directory or file, it is rooted from `/tmp/build/put`. 
* After creating a cluster you'll need to create a `./kube/config` in order to install subsequent capabilities via Helm and Carvel.
  * Consult the output of a `create-cluster/terraform-apply` job/build.
  * Copy the contents into `s3cr3ts/<env>/.kube/config` then execute an `rclone sync`. 

## Roadmap

 * Complete Concourse pipeline definition support for a modest complement of modules found in [tf4k8s](https://github.com/pacphi/tf4k8s) across 
    - [x] AWS (EKS)
    - [x] Azure (AKS)
    - [x] GCP (GKE)
    - [ ] TKG (Azure)
    - [ ] TKG (AWS)
* Adapt existing Concourse pipeline definitions to 
    - [ ] encrypt, mask and securely source secrets (e.g., cloud credentials, .kube/config)
    - [ ] add smoke-tests
* Explore implementation of pipeline definitions supporting other engines 
    - [ ] Jenkins
    - [ ] Tekton
    - [ ] Argo