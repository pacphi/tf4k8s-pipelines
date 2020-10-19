# tf4k8s-pipelines: Starter Concourse Configuration

You basically have to supply two inputs to all the available Concourse pipeline definitions: (a) Terraform variables and (b) Concourse configuration.  Left to your own devices you could certainly figure out what's required, but we want to make this a bit easier to get started.  Adn there's certainly room for improvement.  

## Getting Started 

Unpack the file named `starter-concourse-config.tar.gz`

```
tar -xvf starter-concourse-config.tar.gz -C {some_directory}
```

You'll notice a hierarchical folder structure:

```
+ {some_directory}
  + aks
    + y00
      + ci
      + s3cr3ts
      + tf4k8s-pipelines-config
  + gke
    + z00
      + ci
      + s3cr3ts
      + tf4k8s-pipelines-config
```

It should be apparent that the second-level folder names are the names of managed Kubernetes offerings in public clouds like Azure and Google.  And the third-level folder names are the names of target environments.

Your job will be to replace all occurrences of `REPLACE_ME` with valid values.  You also may want to consider editing the domain and environment (folder) names.

&raquo; [home](../../README.md)