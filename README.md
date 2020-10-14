# tf4k8s-pipelines

Sample GitOps pipelines that employ modules from [tf4k8s](https://github.com/pacphi/tf4k8s) to configure and deploy products and capabilities to targeted Kubernetes clusters.

## Concourse

![Concourse pipelines screenshot](concourse-pipelines.png?raw=true "Concourse pipelines screenshot")

### Spin up a local instance

This script uses [Docker Compose](https://docs.docker.com/compose/install/) to launch a local [Concourse](https://concourse-ci.org/install.html) instance

```
./bin/launch-local-concourse-instance.sh
```

#### Lifecycle management

```
cd .concourse-local
```

##### Stop 

```
docker-compose stop
```

##### Restart

```
docker-compose restart -d
```

##### Teardown

```
docker-compose down
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

### Build and push terraform-resource-with-carvel image

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
* `<username>` and `<password>` are the credentials of an account with read/write privileges to a  container image registry

> A pre-built container image exists on DockerHub, here: [pacphi/terraform-resource-with-carvel](https://hub.docker.com/repository/docker/pacphi/terraform-resource-with-carvel).

### Build and push bby image

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
* `<username>` and `<password>` are the credentials of an account with read/write privileges to a  container image registry

> A pre-built container image exists on DockerHub, here: [pacphi/bby](https://hub.docker.com/repository/docker/pacphi/bby).


### Working with tf4k8s-pipelines

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

gsutil versioning set on gs://s3cr3ts
gsutil versioning set on gs://tf4k8s-pipelines-config
gsutil versioning set on gs://tf4k8s-pipelines-state
```
> * When working with GCS you must enable versioning on each bucket

#### the fly CLI

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
fly -t <target> set-pipeline -p install-tas4k8s -c ./pipelines/gcp/terraformer-with-carvel.yml -l ./ci/n00b/gcp/install-tas4k8s.yml
fly -t <target> unpause-pipeline -p install-tas4k8s
```

#### Lessons learned

* Store secrets like your cloud provider credentials or `./kube/config` (in file format) in a storage bucket.
* Remember to synchronize your local copy of `t4k8s-pipelines-config` when an addition or update is made to one or more `terraform.tfvars` files.
  * Use `rclone sync` with caution. If you don't want to destroy previous state, use `rclone copy` instead.
* Remember that you have to `git commit` and `git push` updates to the `tf4k8s-pipelines` git repository any time you make additions/updates to contents under a) `pipelines` or b) `terraform` directory trees before executing `fly set-pipeline`.
* Remember to execute `fly set-pipeline` any time you a) adapt a pipeline definition or b) edit Concourse configuration
* When using Concourse [terraform-resource](https://github.com/ljfranklin/terraform-resource), if you choose to include a directory or file, it is rooted from `/tmp/build/put`. 
* After creating a cluster you'll need to create a `./kube/config` in order to install subsequent capabilities via Helm and Carvel.
  * Consult the output of a `create-cluster/terraform-apply` job/build.
  * Copy the contents into `s3cr3ts/<env>/.kube/config` then execute an `rclone sync`.

### Addenda

What follows are some other optional experiments you can try out on your own.  

#### Build and push tf4k8s-toolsuite image

```
fly -t <target> set-pipeline -p build-and-push-tf4k8s-toolsuite-image \
    -c ./pipelines/build-and-push-tf4k8s-toolsuite-image.yml \
    --var image-repo-name=<repo-name> \
    --var registry-username=<user> \
    --var registry-password=<password>
fly -t <target> unpause-pipeline -p build-and-push-tf4k8s-toolsuite-image
```

## Roadmap

 * Complete Concourse pipeline definition support for a modest complement of modules found in [tf4k8s](https://github.com/pacphi/tf4k8s) across 
    - [x] AWS (EKS)
    - [x] Azure (AKS)
    - [x] GCP (GKE)
    - [ ] TKG (via TMC)
* Adapt existing Concourse pipeline definitions to 
    - [ ] encrypt, mask and securely source secrets (e.g., cloud credentials, .kube/config)
* Explore implementation of pipeline definitions supporting other engines 
    - [ ] Jenkins
    - [ ] Tekton
    - [ ] Argo