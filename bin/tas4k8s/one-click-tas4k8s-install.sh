#!/usr/bin/env bash

# tf4k8s-pipelines One-click TAS3 Deployment Script
# @author Chris Phillipson
# @version 1.0

# Pre-requisities
## - Cloud provider account admin credentials
## - Concourse instance is up-and-running

# @see https://stackoverflow.com/questions/17484774/indenting-multi-line-output-in-a-shell-script
indent() { sed 's/^/  /'; }

CARVEL_IMAGE="pacphi/terraform-resource-with-carvel"

# Create pipelines config parent directory
TF4K8S_PIPELINES_CONFIG_PARENT_DIR=".tf4k8s"
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR

source $PWD/bin/tas4k8s/one-click-tas4k8s-config.sh

# generate random 7 character alphanumeric string (lowercase only)
SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 7 | head -n 1)

# Make buckets
rclone mkdir $RCLONE_ALIAS:s3cr3ts-$SUFFIX
rclone mkdir $RCLONE_ALIAS:tf4k8s-pipelines-config-$SUFFIX
rclone mkdir $RCLONE_ALIAS:tf4k8s-pipelines-state-$SUFFIX
rclone mkdir $RCLONE_ALIAS:tas4k8s-bundles-$SUFFIX

# Enable bucket versioning
case "$IAAS" in
  aws | tkg/aws)
      aws s3api put-bucket-versioning --bucket s3cr3ts-$SUFFIX --versioning-configuration Status=Enabled
      aws s3api put-bucket-versioning --bucket tf4k8s-pipelines-config-$SUFFIX --versioning-configuration Status=Enabled
      aws s3api put-bucket-versioning --bucket tf4k8s-pipelines-state-$SUFFIX --versioning-configuration Status=Enabled
      aws s3api put-bucket-versioning --bucket tas4k8s-bundles-$SUFFIX --versioning-configuration Status=Enabled
      ;;
      
  azure | tkg/azure)
      az storage account blob-service-properties update --enable-versioning -n $AZ_STORAGE_ACCOUNT_NAME -g $AZ_RESOURCE_GROUP
      ;;
      
  gcp)
      gsutil versioning set on gs://s3cr3ts-$SUFFIX
      gsutil versioning set on gs://tf4k8s-pipelines-config-$SUFFIX
      gsutil versioning set on gs://tf4k8s-pipelines-state-$SUFFIX
      gsutil versioning set on gs://tas4k8s-bundles-$SUFFIX
      ;;
      
  *)
      echo -e "IAAS must be set to one of [ aws, azure, gcp ]"
      exit 1
esac

# Create Terraform module variable file and Concourse pipeline configuration file content
if [ "$IAAS" == "aws" ]; then

COMMON_CI_CONFIG=$(cat <<EOF
uid: $SUFFIX
concourse_url: $CONCOURSE_URL
concourse_username: $CONCOURSE_ADMIN_USERNAME
concourse_password: $CONCOURSE_ADMIN_PASSWORD
concourse_team_name: $CONCOURSE_TEAM
concourse_is_insecure: $IS_CONCOURSE_INSECURE
concourse_is_in_debug_mode: $IS_CONCOURSE_IN_DEBUG_MODE
terraform_resource_with_carvel_image: $CARVEL_IMAGE
registry_username: ""
registry_password: ""
pipeline_repo_branch: main
environment_name: $CONCOURSE_TEAM
aws_region: $AWS_REGION
aws_access_key: $AWS_ACCESS_KEY
aws_secret_key: $AWS_SECRET_KEY
EOF
)

CLUSTER_TFVARS=$(cat <<EOF
eks_name = "$EKS_NAME"
desired_nodes = $EKS_DESIRED_NODES
min_nodes = $EKS_MIN_NODES
max_nodes = $EKS_MAX_NODES
kubernetes_version = "$EKS_K8S_VERSION"
region = "$AWS_REGION"
availability_zones = $AWS_ZONES
ssh_key_name = "$SSH_KEY_NAME"
node_pool_instance_type = "$EKS_NODE_TYPE"
EOF
)

CLUSTER_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-cluster
next_pipeline_name: install-certmanager
next_plan_name: terraform-plan
terraform_module: $IAAS/cluster
s3_bucket_folder: $IAAS/cluster
EOF
)

DNS_TFVARS=$(cat <<EOF
base_hosted_zone_id = "$AWS_ROUTE53_BASED_HOSTED_ZONE_ID"
dns_prefix = "$SUB_NAME"
EOF
)

DNS_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-dns
next_pipeline_name: create-cluster
next_plan_name: terraform-plan
terraform_module: $IAAS/dns
s3_bucket_folder: $IAAS/dns
EOF
)

CERTMGR_TFVARS=$(cat <<EOF
access_key = "$AWS_ACCESS_KEY"
secret_key = "$AWS_SECRET_KEY"
region = "$AWS_REGION"
domain = "$SUB_DOMAIN"
# TODO Fetch zone id
# Need to fetch this somehow from Terraform state metadata of create-dns pipeline
# hosted_zone_id = ""
acme_email = "$EMAIL_ADDRESS"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

CERTMGR_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-certmanager
next_pipeline_name: install-nginx-ingress-controller
next_plan_name: terraform-plan
terraform_module: $IAAS/certmanager
s3_bucket_folder: $IAAS/certmanager
EOF
)

EXTERNAL_DNS_TFVARS=$(cat <<EOF
domain_filter = "$SUB_DOMAIN"
aws_access_key = "$AWS_ACCESS_KEY"
aws_secret_key = "$AWS_SECRET_KEY"
region = "$AWS_REGION"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

EXTERNAL_DNS_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-external-dns
next_pipeline_name: install-harbor
next_plan_name: terraform-plan
terraform_module: $IAAS/external-dns
s3_bucket_folder: $IAAS/external-dns
EOF
)

HARBOR_TFVARS=$(cat <<EOF
domain = "$SUB_DOMAIN"
ingress = "nginx"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

HARBOR_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-harbor
next_pipeline_name: install-tas4k8s
next_plan_name: acme-tf-plan
terraform_module: k8s/harbor
s3_bucket_folder: k8s/harbor
EOF
)

NIC_TFVARS=$(cat <<EOF
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

NIC_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-nginx-ingress-controller
next_pipeline_name: install-external-dns
next_plan_name: terraform-plan
terraform_module: k8s/nginx-ingress-controller
s3_bucket_folder: k8s/nginx-ingress-controller
EOF
)

TAS4K8S_TFVARS=$(cat <<EOF
base_domain = "$SUB_DOMAIN"
registry_domain = "harbor.$SUB_DOMAIN"
repository_prefix = "harbor.$SUB_DOMAIN/library"
registry_username = "admin"
registry_password = ""
pivnet_username = "$EMAIL_ADDRESS"
pivnet_password = "$TANZU_NETWORK_ACCOUNT_PASSWORD"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
path_to_certs_and_keys = "/tmp/build/put/ck/certs-and-keys.vars"
ytt_lib_dir = "/tmp/build/put/tas4k8s-repo/ytt-libs"
EOF
)

TAS4K8S_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-tas4k8s
product_version: 3\.1\.0\-build\.*
bby_image: pacphi/bby
tanzu_network_api_token: $TANZU_NETWORK_API_TOKEN
scripts_repo_branch: master
s3_bucket_folder: harbor
registry_password_tfvar_name: harbor_admin_password
EOF
)

ACME_TFVARS=$(cat <<EOF
base_domain = "$SUB_DOMAIN"
# TODO Fetch zone id
# Need to fetch this somehow from Terraform state metadata of create-dns pipeline
# dns_zone_id = ""
email = "$EMAIL_ADDRESS"
region = "$AWS_REGION"
path_to_certs_and_keys = "$CONCOURSE_TEAM/terraform/k8s/tas4k8s/certs-and-keys.vars"
uid = "$SUFFIX"
EOF
)

fi

if [ "$IAAS" == "gcp" ]; then

GCP_SA_KEY_FILE_PATH="$HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/s3cr3ts/$CONCOURSE_TEAM/$GCP_SERVICE_ACCOUNT.$GCP_PROJECT.json"
GCP_SA_KEY_REMOTE_FILE_PATH="/tmp/build/put/gcloud-credentials/$GCP_SERVICE_ACCOUNT.$GCP_PROJECT.json"
GCP_SA_KEY_CONTENTS="$(cat $GCP_SA_KEY_FILE_PATH)"

COMMON_CI_CONFIG=$(cat <<EOF
uid: $SUFFIX
concourse_url: $CONCOURSE_URL
concourse_username: $CONCOURSE_ADMIN_USERNAME
concourse_password: $CONCOURSE_ADMIN_PASSWORD
concourse_team_name: $CONCOURSE_TEAM
concourse_is_insecure: $IS_CONCOURSE_INSECURE
concourse_is_in_debug_mode: $IS_CONCOURSE_IN_DEBUG_MODE
terraform_resource_with_carvel_image: $CARVEL_IMAGE
registry_username: ""
registry_password: ""
pipeline_repo_branch: main
environment_name: $CONCOURSE_TEAM
gcp_service_account_key_filename: $GCP_SERVICE_ACCOUNT.$GCP_PROJECT.json
gcp_account_key_json: |
EOF
)

CLUSTER_TFVARS=$(cat <<EOF
gcp_project = "$GCP_PROJECT"
gcp_region = "$GCP_REGION"
gke_name = "$K8S_ENV"
gke_nodes = $GKE_NODES
gke_preemptible = false
gke_node_type = "$GKE_NODE_TYPE"
gcp_service_account_credentials = "$GCP_SA_KEY_REMOTE_FILE_PATH"
EOF
)

CLUSTER_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-cluster
next_pipeline_name: install-certmanager
next_plan_name: terraform-plan
terraform_module: $IAAS/cluster
gcp_storage_bucket_folder: $IAAS/cluster
EOF
)

DNS_TFVARS=$(cat <<EOF
project = "$GCP_PROJECT"
root_zone_name = "$BASE_NAME-zone"
environment_name = "$SUB_NAME"
dns_prefix = "$SUB_NAME"
gcp_service_account_credentials = "$GCP_SA_KEY_REMOTE_FILE_PATH"
EOF
)

DNS_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-dns
next_pipeline_name: create-cluster
next_plan_name: terraform-plan
terraform_module: $IAAS/dns
gcp_storage_bucket_folder: $IAAS/dns
EOF
)

CERTMGR_TFVARS=$(cat <<EOF
project = "$GCP_PROJECT"
domain = "$SUB_DOMAIN"
acme_email = "$EMAIL_ADDRESS"
dns_zone_name = "$SUB_NAME-zone"
gcp_service_account_credentials = "$GCP_SA_KEY_REMOTE_FILE_PATH"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

CERTMGR_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-certmanager
next_pipeline_name: install-nginx-ingress-controller
next_plan_name: terraform-plan
terraform_module: $IAAS/certmanager
gcp_storage_bucket_folder: $IAAS/certmanager
EOF
)

EXTERNAL_DNS_TFVARS=$(cat <<EOF
domain_filter = "$SUB_DOMAIN"
gcp_project = "$GCP_PROJECT"
gcp_service_account_credentials = "$GCP_SA_KEY_REMOTE_FILE_PATH"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

EXTERNAL_DNS_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-external-dns
next_pipeline_name: install-harbor
next_plan_name: terraform-plan
terraform_module: $IAAS/external-dns
gcp_storage_bucket_folder: $IAAS/external-dns
EOF
)

HARBOR_TFVARS=$(cat <<EOF
domain = "$SUB_DOMAIN"
ingress = "nginx"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

HARBOR_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-harbor
next_pipeline_name: install-tas4k8s
next_plan_name: acme-tf-plan
terraform_module: k8s/harbor
gcp_storage_bucket_folder: k8s/harbor
EOF
)

NIC_TFVARS=$(cat <<EOF
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

NIC_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-nginx-ingress-controller
next_pipeline_name: install-external-dns
next_plan_name: terraform-plan
terraform_module: k8s/nginx-ingress-controller
gcp_storage_bucket_folder: k8s/nginx-ingress-controller
EOF
)

TAS4K8S_TFVARS=$(cat <<EOF
base_domain = "$SUB_DOMAIN"
registry_domain = "harbor.$SUB_DOMAIN"
repository_prefix = "harbor.$SUB_DOMAIN/library"
registry_username = "admin"
registry_password = ""
pivnet_username = "$EMAIL_ADDRESS"
pivnet_password = "$TANZU_NETWORK_ACCOUNT_PASSWORD"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
path_to_certs_and_keys = "/tmp/build/put/ck/certs-and-keys.vars"
ytt_lib_dir = "/tmp/build/put/tas4k8s-repo/ytt-libs"
EOF
)

TAS4K8S_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-tas4k8s
product_version: 3\.1\.0\-build\.*
bby_image: pacphi/bby
tanzu_network_api_token: $TANZU_NETWORK_API_TOKEN
scripts_repo_branch: master
gcp_storage_bucket_folder: harbor
registry_password_tfvar_name: harbor_admin_password
EOF
)

ACME_TFVARS=$(cat <<EOF
email = "$EMAIL_ADDRESS"
base_domain = "$SUB_DOMAIN"
project = "$GCP_PROJECT"
path_to_certs_and_keys = "$CONCOURSE_TEAM/terraform/k8s/tas4k8s/certs-and-keys.vars"
uid = "$SUFFIX"
EOF
)

fi


## TODO Add Azure specific TFVARS and CI_CONFIG


# Place Terraform module variable files and Concourse pipeline configuration files
mkdir -p ci/$CONCOURSE_TEAM/$IAAS
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/dns
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/cluster
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/certmanager
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/nginx-ingress-controller
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/external-dns
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/harbor
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/tas4k8s/acme

mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/s3cr3ts/$CONCOURSE_TEAM/.kube
touch $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/s3cr3ts/$CONCOURSE_TEAM/.kube/config

echo -e "$COMMON_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/common.yml

if [ "$IAAS" == "gcp" ]; then
  echo $GCP_SA_KEY_CONTENTS | indent >> $PWD/ci/$CONCOURSE_TEAM/$IAAS/common.yml
fi

echo -e "$DNS_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/create-dns.yml
echo -e "$CLUSTER_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/create-cluster.yml
echo -e "$CERTMGR_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/install-certmanager.yml
echo -e "$NIC_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/install-nginx-ingress-controller.yml
echo -e "$EXTERNAL_DNS_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/install-external-dns.yml
echo -e "$HARBOR_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/install-harbor.yml
echo -e "$TAS4K8S_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/install-tas4k8s.yml

echo -e "$DNS_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/dns/terraform.tfvars
echo -e "$CLUSTER_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/cluster/terraform.tfvars
echo -e "$CERTMGR_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/certmanager/terraform.tfvars
echo -e "$NIC_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/nginx-ingress-controller/terraform.tfvars
echo -e "$EXTERNAL_DNS_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/external-dns/terraform.tfvars
echo -e "$HARBOR_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/harbor/terraform.tfvars
echo -e "$ACME_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/tas4k8s/acme/terraform.tfvars
echo -e "$TAS4K8S_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/tas4k8s/terraform.tfvars

## TODO Source and/or create and copy IAAS service account credentials into place

# Sync local config directory to bucket
rclone sync $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config $RCLONE_ALIAS:tf4k8s-pipelines-config-$SUFFIX --auto-confirm
rclone sync $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/s3cr3ts $RCLONE_ALIAS:s3cr3ts-$SUFFIX --auto-confirm

CONCOURSE_ENDPOINT=$CONCOURSE_URL
if [ "$CONCOURSE_URL" == "http://web:8080" ] || [ -z $CONCOURSE_URL ]; then
  CONCOURSE_ENDPOINT="http://localhost:8080"
fi

# First login to Concourse instance
fly -t $CONCOURSE_ALIAS login --concourse-url $CONCOURSE_ENDPOINT -u $CONCOURSE_ADMIN_USERNAME -p $CONCOURSE_ADMIN_PASSWORD
# Create a new team
fly -t $CONCOURSE_ALIAS set-team --team-name $CONCOURSE_TEAM --local-user $CONCOURSE_ADMIN_USERNAME --non-interactive

# Set pipelines
fly -t $CONCOURSE_ALIAS set-pipeline -p create-dns -c ./pipelines/$IAAS/linkable-terraformer.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/create-dns.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p create-cluster -c ./pipelines/$IAAS/linkable-cluster.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/create-cluster.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-certmanager -c ./pipelines/$IAAS/linkable-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/install-certmanager.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-nginx-ingress-controller -c ./pipelines/$IAAS/linkable-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/install-nginx-ingress-controller.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-external-dns -c ./pipelines/$IAAS/linkable-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/install-external-dns.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-harbor -c ./pipelines/$IAAS/linkable-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/install-harbor.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-tas4k8s -c ./pipelines/$IAAS/linkable-tas4k8s.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/install-tas4k8s.yml --team=$CONCOURSE_TEAM --non-interactive

# Log in again targeting team
fly -t $CONCOURSE_ALIAS login --concourse-url $CONCOURSE_ENDPOINT -u $CONCOURSE_ADMIN_USERNAME -p $CONCOURSE_ADMIN_PASSWORD --team-name=$CONCOURSE_TEAM

# Kick off first pipeline
fly -t $CONCOURSE_ALIAS unpause-pipeline -p create-dns