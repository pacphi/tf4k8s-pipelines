# tf4k8s-pipelines

Sample GitOps pipelines that employ modules from tf4k8s to configure and deploy products and capabilities to targeted Kubernetes clusters

## Concourse

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

### Build and push tf4k8s-toolsuite image

```
fly -t <target> set-pipeline -p build-and-push-tf4k8s-toolsuite-image \
    -c ./pipelines/build-and-push-tf4k8s-toolsuite-image.yml \
    --var image-repo-name=<repo-name> \
    --var registry-username=<user> \
    --var registry-password=<password>
fly -t <target> unpause-pipeline -p build-and-push-tf4k8s-toolsuite-image
```

* `<target>` is the alias for the connection details to a Concourse instance
* `<repo-name>` is a Container Image Repository prefix (e.g., harbor.envy.ironleg.me/library)
* `<username>` and `<password>` is the username of an account with read/write privileges to a Container Image Registry

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

Place a `terraform.tfvars` file in each of the subdirectories you wish to drive a `terraform` `plan` or `apply`.

For example:

```
+ tf4k8s-pipelines-config
  + n00b
    + gcp
      + dns
        - terraform.tfvars
```

Now we'll also want to manage state, so rinse-and-repeat the steps above to create a new root directory, environment subdirectory, and subdirectories for each module. Then, we'll want to place an empty `terraform.tfstate` file in each module sub-directory.

For example:

```
+ tf4k8s-pipelines-state
  + n00b
    + gcp
      + dns
        - terraform.tfstate
```

Use [rclone](https://rclone.org/) to synchronize your local configuration (and in some instances credentials) with a cloud storage provider of your choice.

Execute `rclone config` to configure a target storage provider.

You could create a bucket with `rclone mkdir <target>:<bucket_name>`.

And you could sync with `rclone sync -i /path/to/config <target>:<bucket_name>`

For example, when working with Google Cloud Storage (GCS)...

```
rclone mkdir fe-cphillipson-gcs:tf4k8s-pipelines-config
rclone sync -i /home/cphillipson/Documents/development/pivotal/tanzu/tf4k8s-pipelines-config fe-cphillipson-gcs:tf4k8s-pipelines-config
rclone mkdir fe-cphillipson-gcs:tf4k8s-pipelines-state
rclone sync -i /home/cphillipson/Documents/development/pivotal/tanzu/tf4k8s-pipelines-state fe-cphillipson-gcs:tf4k8s-pipelines-state

gsutil versioning set on gs://tf4k8s-pipelines-config
gsutil versioning set on gs://tf4k8s-pipelines-state
```
> * When working with GCS you must enable versioning on each bucket

#### Flying pipelines

We'll continue to use the fly CLI to upload pipeline definitions with configuration (in this case we're talking about Concourse YAML [configuration](https://concourse-ci.org/config-basics.html#basic-schemas)).

All pipeline definitions in this repository are found in the [pipelines](https://github.com/pacphi/tf4k8s-pipelines/tree/main/pipelines) directory.  As mentioned each pipeline is the realization of a definition and configuration (i.e., any value encapsulated in `(())` or `{{}}`), so inspect the yaml for each definition to see what's expected.

Terraform modules are found in the [terraform](https://github.com/pacphi/tf4k8s-pipelines/tree/main/terraform) directory.

For convenience we'll want to create a `ci` sub-directory to collect all our configuration. And for practical purposes we'll want to create a subdirectory structure that mirrors what created earlier, so something like:

```
+ tf4k8s-pipelines
  + ci
    + n00b
      + gcp
        - create-dns.yml
```

So putting this into practice, if we wanted to create a new Cloud DNS zone in Google Cloud, we could execute 

```
fly -t <target> set-pipeline -p create-dns -c ./pipelines/gcp/terraformer.yml -l ./ci/n00b/gcp/create-dns.yml
fly -t <target> unpause-pipeline -p create-dns
```

#### Lessons learned

* Store secrets like your cloud provider credentials or `./kube/config` (in file format) in a storage bucket.
* Remember to synchronize your local copy of `t4k8s-pipelines-config` when an addition or update is made to one or more `terraform.tfvars` files.
  * Use `rclone sync` with caution. If you don't want to destroy previous state, use `rclone copy` instead.
* When initializing a new folder underneath `t4k8s-pipelines-state` with `terraform.tfstate` make sure you skip deletions on `rclone sync`.
* Remember that you have to ``git commit` and `git push` updates to the `tf4k8s-pipelines` git repository any time you add or update a `main.tf`.
* Remember to execute `fly set-pipeline` any time you a) adapt a pipeline definition or b) edit Concourse configuration
* When using Concourse [terraform-resource](https://github.com/ljfranklin/terraform-resource), if you choose to include a directory or file, it is rooted from `/tmp/build/put`. 