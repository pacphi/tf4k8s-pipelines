# tf4k8s-pipelines: Starter Concourse Configuration

You basically have to supply two inputs to all the available Concourse pipeline definitions: (a) Terraform variables and (b) Concourse configuration.  Left to your own devices you could certainly figure out what's required, but we want to make this a bit easier to get started (there's certainly room for improvement).  

## Getting Started 

Unpack the file named [concourse-starter-config.zip](concourse-starter-config.zip)

```
unzip concourse-starter-config.zip -d {some_directory}
```

You'll notice a hierarchical folder structure:

```
+ {some_directory}
  + aks
    + ci
      + y00
    + s3cr3ts
      + y00
    + tf4k8s-pipelines-config
      + y00
  + eks
    + ci
      + x00
    + s3cr3ts
      + x00
    + tf4k8s-pipelines-config
      + x00
  + gke
    + ci
      + z00
    + s3cr3ts
      + z00
    + tf4k8s-pipelines-config
      + z00
  + tkg
    + aws
      + ci
        + b00
      + s3cr3ts
        + b00
      + tf4k8s-pipelines-config
        + b00
    + azure
      + ci
        + a00
      + s3cr3ts
        + a00
      + tf4k8s-pipelines-config
        + a00
```

It should be apparent that the second-level folder names are the names of managed Kubernetes offerings in public clouds like Azure and Google.  And the fourth-level folder names are the names of target environments.  (The only exception to this convention is the `tkg` subdirectory tree).

Your job will be to edit various configuration files and replace all occurrences of `REPLACE_ME` with valid values.  You also may want to consider editing the domain and environment (folder) names.


## Idiosyncrasies of public clouds

Getting Kubernetes dial-tone on a cloud of your choice is a non-event in most cases.  Depending on the cloud provider, the `kubeconfig` that gets returned from a successful run of the `terraform-apply` job in a cloud-specific `create-cluster` pipeline may expire before you get a chance to configure and run other pipelines that install capabilities like: `certmanager`, `nginx-ingress-controller`, or `external-dns`.  Let's see how we can handle that eventuality per cloud provider.

### Amazon EKS

Install [eksctl](https://docs.aws.amazon.com/eks/latest/userguide/getting-started-eksctl.html).

Use `eksctl utils write-kubeconfig --cluster {cluster_name}` to generate an entry in `~/.kube/config` where user authentication gets delegated to [aws-iam-authenticator](https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html) in order to allow access to a named cluster.  Copy the contents to the appropriate `s3cr3ts/{env}/.kube` directory to a file named `config`.  Use `rclone sync` to get this config into an S3 bucket container.

### Azure AKS

By default, AKS clusters are created with a service principal that has a one-year expiration time.  Use `az aks get-credentials --admin --name {cluster_name} --resource-group {resource_group_name}`.  Likewise copy the content of `~/.kube/config` to the appropriate `s3cr3ts/{env}/.kube` directory to a file named `config`.  Use `rclone sync` to get this config into an Azure Blob Storage container.

Consult these articles for more information:

* [Update or rotate the credentials for Azure Kubernetes Service (AKS)](https://docs.microsoft.com/en-us/azure/aks/update-credentials)
* [Available cluster roles permissions](https://docs.microsoft.com/en-us/azure/aks/control-kubeconfig-access#available-cluster-roles-permissions)

### Google GKE

The current implementation of the Terraform provider returns cluster credentials without further need to refresh.


&raquo; [home](../../README.md)