#!/usr/bin/env bash

# tf4k8s-pipelines One-click TAS3 Deployment Script
# @author Chris Phillipson
# @version 1.0

# Prerequisities:
## - *nix OS
## - Public Internet access
## - Cloud provider CLI installed (e.g., aws, az, gcloud, tkg)
## - Cloud provider account admin credentials
## - Tanzu Network credentials and API token
## - docker and docker-compose installed if you want to run a local Concourse instance
## - Concourse instance is up-and-running
## - rclone CLI installed
## - Already configured rclone to interact with cloud provider storage API

# @see https://stackoverflow.com/questions/17484774/indenting-multi-line-output-in-a-shell-script
indent() { sed 's/^/  /'; }

mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR

source $PWD/bin/tas4k8s/one-click-tas4k8s-config.sh

# generate random 7 character alphanumeric string (lowercase only)
SUFFIX=$(cat /dev/urandom | tr -dc 'a-z0-9' | fold -w 7 | head -n 1)

# Make buckets
rclone mkdir $RCLONE_ALIAS:s3cr3ts-$SUFFIX
rclone mkdir $RCLONE_ALIAS:tf4k8s-pipelines-config-$SUFFIX
rclone mkdir $RCLONE_ALIAS:tf4k8s-pipelines-state-$SUFFIX
rclone mkdir $RCLONE_ALIAS:tas4k8s-bundles-$SUFFIX

# Authenticate, create service account, enable bucket versioning
case "$IAAS" in
  aws | tkg/aws)
      export AWS_PAGER=""
      # Thanks to https://docs.aws.amazon.com/IAM/latest/UserGuide/getting-started_create-admin-group.html and https://docs.aws.amazon.com/IAM/latest/UserGuide/id_users_create.html
      aws configure
      aws iam create-group --group-name Admins
      aws iam attach-group-policy --group-name Admins --policy-arn arn:aws:iam::aws:policy/AdministratorAccess
      aws iam create-user –-user-name $AWS_SERVICE_ACCOUNT
      aws create-login-profile --username $AWS_SERVICE_ACCOUNT --password $AWS_SERVICE_ACCOUNT_PASSWORD --no-password-reset-required true
      aws iam add-user-to-group --user-name $AWS_SERVICE_ACCOUNT --group-name Admins
      aws iam create-access-key --user-name $AWS_SERVICE_ACCOUNT > key.txt
      AWS_ACCESS_KEY=$(cat key.txt | jq -r ".AccessKey.AccessKeyId")
      AWS_SECRET_KEY=$(cat key.txt | jq -r ".AccessKey.SecretAccessKey")
      rm -rf key.txt

      aws s3api put-bucket-versioning --bucket s3cr3ts-$SUFFIX --versioning-configuration Status=Enabled
      aws s3api put-bucket-versioning --bucket tf4k8s-pipelines-config-$SUFFIX --versioning-configuration Status=Enabled
      aws s3api put-bucket-versioning --bucket tf4k8s-pipelines-state-$SUFFIX --versioning-configuration Status=Enabled
      aws s3api put-bucket-versioning --bucket tas4k8s-bundles-$SUFFIX --versioning-configuration Status=Enabled
      ;;
      
  azure | tkg/azure)
      # Thanks to https://markheath.net/post/create-service-principal-azure-cli
      az login
      az account set -s $AZ_SUBSCRIPTION_ID
      az ad app create --display-name $AZ_APP_NAME --homepage "http://localhost/$AZ_APP_NAME"
      AZ_APP_ID=$(az ad app list --display-name $AZ_APP_NAME --query [].appId -o tsv)
      az ad sp create-for-rbac --name $AZ_APP_ID --password "$AZ_CLIENT_SECRET" --role="Contributor" --scopes="/subscriptions/$AZ_SUBSCRIPTION_ID/resourceGroups/$AZ_RESOURCE_GROUP"
      AZ_CLIENT_ID=$(az ad sp list --display-name $AZ_APP_ID --query "[].appId" -o tsv)
      
      az storage account blob-service-properties update --enable-versioning -n $AZ_STORAGE_ACCOUNT_NAME -g $AZ_RESOURCE_GROUP
      ;;
      
  gcp)
      gcloud auth login
      gcloud iam service-accounts create $GCP_SERVICE_ACCOUNT
      gcloud projects add-iam-policy-binding $GCP_PROJECT --member="serviceAccount:$GCP_SERVICE_ACCOUNT@$GCP_PROJECT.iam.gserviceaccount.com" --role="roles/owner"
      gcloud iam service-accounts keys create $GCP_SERVICE_ACCOUNT.$GCP_PROJECT.json --iam-account=$GCP_SERVICE_ACCOUNT@$GCP_PROJECT.iam.gserviceaccount.com
      mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/s3cr3ts/$CONCOURSE_TEAM
      mv $GCP_SERVICE_ACCOUNT.$GCP_PROJECT.json $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/s3cr3ts/$CONCOURSE_TEAM

      gsutil versioning set on gs://s3cr3ts-$SUFFIX
      gsutil versioning set on gs://tf4k8s-pipelines-config-$SUFFIX
      gsutil versioning set on gs://tf4k8s-pipelines-state-$SUFFIX
      gsutil versioning set on gs://tas4k8s-bundles-$SUFFIX
      ;;
      
  *)
      echo -e "IAAS must be set to one of [ aws, azure, gcp, tkg/aws, tkg/azure ]"
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
pipeline_repo_branch: $TF4K8S_PIPELINE_REPO_BRANCH
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
base_hosted_zone_id = "$AWS_ROUTE53_BASE_HOSTED_ZONE_ID"
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
hosted_zone_id = ""
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
zone_id_variable_name: hosted_zone_id
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
product_version: $TAS4K8S_VERSION
bby_image: pacphi/bby
tanzu_network_api_token: $TANZU_NETWORK_API_TOKEN
scripts_repo_branch: master
s3_bucket_folder: harbor
registry_password_tfvar_name: harbor_admin_password
zone_id_variable_name: dns_zone_id
EOF
)

ACME_TFVARS=$(cat <<EOF
base_domain = "$SUB_DOMAIN"
dns_zone_id = ""
email = "$EMAIL_ADDRESS"
region = "$AWS_REGION"
path_to_certs_and_keys = "$CONCOURSE_TEAM/terraform/k8s/tas4k8s/certs-and-keys.vars"
uid = "$SUFFIX"
EOF
)

fi

if [ "$IAAS" == "azure" ]; then

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
pipeline_repo_branch: $TF4K8S_PIPELINE_REPO_BRANCH
environment_name: $CONCOURSE_TEAM
storage_account_name: $AZ_STORAGE_ACCOUNT_NAME
storage_account_key: $AZ_STORAGE_ACCOUNT_KEY
EOF
)

CLUSTER_TFVARS=$(cat <<EOF
aks_resource_group = "$AZ_RESOURCE_GROUP"
enable_logs = false
ssh_public_key = "/tmp/build/put/pk/az_rsa.pub"
az_subscription_id = $AZ_SUBSCRIPTION_ID
az_tenant_id = "$AZ_TENANT_ID"
az_client_id = "$AZ_CLIENT_ID"
az_client_secret = "$AZ_CLIENT_SECRET"
aks_region = "$AZ_REGION"
aks_name = "$K8S_ENV"
aks_nodes = $AKS_NODES
aks_node_type = $AKS_NODE_TYPE
aks_pool_name = "$K8S_ENVpool"
aks_node_disk_size = 30
EOF
)

CLUSTER_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-cluster
next_pipeline_name: install-certmanager
next_plan_name: terraform-plan
terraform_module: $IAAS/cluster
azure_storage_bucket_folder: $IAAS/cluster
EOF
)

DNS_TFVARS=$(cat <<EOF
base_domain = "$BASE_DOMAIN"
domain_prefix = "$SUB_NAME"
resource_group_name = "$AZ_RESOURCE_GROUP"
az_subscription_id = "$AZ_SUBSCRIPTION_ID"
az_tenant_id = "$AZ_TENANT_ID"
az_client_id = "$AZ_CLIENT_ID"
az_client_secret = "$AZ_CLIENT_SECRET"
EOF
)

DNS_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-dns
next_pipeline_name: create-cluster
next_plan_name: terraform-plan
terraform_module: $IAAS/dns
azure_storage_bucket_folder: $IAAS/dns
EOF
)

CERTMGR_TFVARS=$(cat <<EOF
az_subscription_id = "$AZ_SUBSCRIPTION_ID"
az_tenant_id = "$AZ_TENANT_ID"
az_client_id = "$AZ_CLIENT_ID"
az_client_secret = "$AZ_CLIENT_SECRET"
cluster_issuer_resource_group = "$AZ_RESOURCE_GROUP"
domain = "$SUB_DOMAIN"
acme_email = "$EMAIL_ADDRESS"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

CERTMGR_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-certmanager
next_pipeline_name: install-nginx-ingress-controller
next_plan_name: terraform-plan
terraform_module: $IAAS/certmanager
azure_storage_bucket_folder: $IAAS/certmanager
EOF
)

EXTERNAL_DNS_TFVARS=$(cat <<EOF
domain_filter = "$SUB_DOMAIN"
resource_group_name = "$AZ_RESOURCE_GROUP"
az_subscription_id = "$AZ_SUBSCRIPTION_ID"
az_tenant_id = "$AZ_TENANT_ID"
az_client_id = "$AZ_CLIENT_ID"
az_client_secret = "$AZ_CLIENT_SECRET"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

EXTERNAL_DNS_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-external-dns
next_pipeline_name: install-harbor
next_plan_name: terraform-plan
terraform_module: $IAAS/external-dns
azure_storage_bucket_folder: $IAAS/external-dns
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
azure_storage_bucket_folder: k8s/harbor
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
azure_storage_bucket_folder: k8s/nginx-ingress-controller
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
product_version: $TAS4K8S_VERSION
bby_image: pacphi/bby
tanzu_network_api_token: $TANZU_NETWORK_API_TOKEN
scripts_repo_branch: master
azure_storage_bucket_folder: harbor
registry_password_tfvar_name: harbor_admin_password
EOF
)

ACME_TFVARS=$(cat <<EOF
base_domain = "$SUB_DOMAIN"
email = "$EMAIL_ADDRESS"
storage_account_name = "$AZ_STORAGE_ACCOUNT_NAME"
subscription_id = "$AZ_SUBSCRIPTION_ID"
tenant_id = "$AZ_TENANT_ID"
client_id = "$AZ_CLIENT_ID"
client_secret = "$AZ_CLIENT_SECRET"
resource_group_name = "$AZ_RESOURCE_GROUP"
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
pipeline_repo_branch: $TF4K8S_PIPELINE_REPO_BRANCH
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
product_version: $TAS4K8S_VERSION
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

if [ "$IAAS" == "tkg/aws" ]; then

COMMON_CI_CONFIG=$(cat <<EOF
uid: $SUFFIX
concourse_url: $CONCOURSE_URL
concourse_username: $CONCOURSE_ADMIN_USERNAME
concourse_password: $CONCOURSE_ADMIN_PASSWORD
concourse_team_name: $CONCOURSE_TEAM
concourse_is_insecure: $IS_CONCOURSE_INSECURE
concourse_is_in_debug_mode: $IS_CONCOURSE_IN_DEBUG_MODE
terraform_resource_with_tkg_image: $TKG_IMAGE
terraform_resource_with_carvel_image: $CARVEL_IMAGE
registry_username: ""
registry_password: ""
pipeline_repo_branch: $TF4K8S_PIPELINE_REPO_BRANCH
environment_name: $CONCOURSE_TEAM
aws_region: $AWS_REGION
aws_access_key: $AWS_ACCESS_KEY
aws_secret_key: $AWS_SECRET_KEY
EOF
)

MGMT_CLUSTER_TFVARS=$(cat <<EOF
path_to_tkg_config_yaml = "~/.tf4k8s/tkg/$CONCOURSE_TEAM/config.yaml"
aws_ssh_key_name = "tkg-aws-$AWS_REGION.pem"
tkg_plan = "$TKG_PLAN"
tkg_kubernetes_version = "$TKG_K8S_VERSION"
control_plan_machine_type = "$TKG_CONTROL_PLANE_MACHINE_TYPE"
node_machine_type = "$TKG_WORKER_NODE_MACHINE_TYPE"
aws_node_az = "$AWS_NODE_AZ"
aws_node_az_1 = "$AWS_NODE_AZ_1"
aws_node_az_2 = "$AWS_NODE_AZ_2"
aws_secret_key_id = "$AWS_ACCESS_KEY"
aws_secret_access_key = "$AWS_SECRET_KEY"
EOF
)

MGMT_CLUSTER_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-management-cluster
next_pipeline_name: create-workload-cluster
next_plan_name: terraform-plan
terraform_module: $IAAS/cluster
s3_bucket_folder: $IAAS/cluster
EOF
)

WKLD_CLUSTER_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-workload-cluster
next_pipeline_name: install-certmanager
next_plan_name: terraform-plan
terraform_module: $IAAS/cluster
s3_bucket_folder: $IAAS/cluster
EOF
)

WKLD_CLUSTER_TFVARS=$(cat <<EOF
environment = "$CONCOURSE_TEAM"
path_to_tkg_config_yaml = "/tmp/build/put/tkg-config/config.yaml"
tkg_plan = "$TKG_PLAN"
tkg_control_plane_node_count = $TKG_CONTROL_PLANE_NODE_COUNT
tkg_worker_node_count = $TKG_WORKER_NODE_COUNT
EOF
)

DNS_TFVARS=$(cat <<EOF
base_hosted_zone_id = "$AWS_ROUTE53_BASE_HOSTED_ZONE_ID"
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
hosted_zone_id = ""
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
zone_id_variable_name: hosted_zone_id
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
product_version: $TAS4K8S_VERSION
bby_image: pacphi/bby
tanzu_network_api_token: $TANZU_NETWORK_API_TOKEN
scripts_repo_branch: master
s3_bucket_folder: harbor
registry_password_tfvar_name: harbor_admin_password
zone_id_variable_name: dns_zone_id
EOF
)

ACME_TFVARS=$(cat <<EOF
base_domain = "$SUB_DOMAIN"
dns_zone_id = ""
email = "$EMAIL_ADDRESS"
region = "$AWS_REGION"
path_to_certs_and_keys = "$CONCOURSE_TEAM/terraform/k8s/tas4k8s/certs-and-keys.vars"
uid = "$SUFFIX"
EOF
)

fi

if [ "$IAAS" == "tkg/azure" ]; then

COMMON_CI_CONFIG=$(cat <<EOF
uid: $SUFFIX
concourse_url: $CONCOURSE_URL
concourse_username: $CONCOURSE_ADMIN_USERNAME
concourse_password: $CONCOURSE_ADMIN_PASSWORD
concourse_team_name: $CONCOURSE_TEAM
concourse_is_insecure: $IS_CONCOURSE_INSECURE
concourse_is_in_debug_mode: $IS_CONCOURSE_IN_DEBUG_MODE
terraform_resource_with_tkg_image: $TKG_IMAGE
terraform_resource_with_carvel_image: $CARVEL_IMAGE
registry_username: ""
registry_password: ""
pipeline_repo_branch: $TF4K8S_PIPELINE_REPO_BRANCH
environment_name: $CONCOURSE_TEAM
storage_account_name: $AZ_STORAGE_ACCOUNT_NAME
storage_account_key: $AZ_STORAGE_ACCOUNT_KEY
EOF
)

MGMT_CLUSTER_TFVARS=$(cat <<EOF
az_resource_group = "$AZ_RESOURCE_GROUP"
path_to_tkg_config_yaml = "~/.tf4k8s/tkg/$CONCOURSE_TEAM/config.yaml"
path_to_az_ssh_public_key = "/tmp/build/put/pk/az_rsa.pub"
az_location = $AZ_REGION
az_subscription_id = $AZ_SUBSCRIPTION_ID
az_tenant_id = "$AZ_TENANT_ID"
az_client_id = "$AZ_CLIENT_ID"
az_client_secret = "$AZ_CLIENT_SECRET"
tkg_plan = "$TKG_PLAN"
tkg_kubernetes_version = "$TKG_K8S_VERSION"
control_plan_machine_type = "$TKG_CONTROL_PLANE_MACHINE_TYPE"
node_machine_type = "$TKG_WORKER_NODE_MACHINE_TYPE"
EOF
)

MGMT_CLUSTER_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-management-cluster
next_pipeline_name: create-workload-cluster
next_plan_name: terraform-plan
terraform_module: $IAAS/cluster
azure_storage_bucket_folder: $IAAS/cluster
EOF
)

WKLD_CLUSTER_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-workload-cluster
next_pipeline_name: install-certmanager
next_plan_name: terraform-plan
terraform_module: $IAAS/cluster
azure_storage_bucket_folder: $IAAS/cluster
EOF
)

WKLD_CLUSTER_TFVARS=$(cat <<EOF
environment = "$CONCOURSE_TEAM"
path_to_tkg_config_yaml = "/tmp/build/put/tkg-config/config.yaml"
tkg_plan = "$TKG_PLAN"
tkg_control_plane_node_count = $TKG_CONTROL_PLANE_NODE_COUNT
tkg_worker_node_count = $TKG_WORKER_NODE_COUNT
EOF
)

DNS_TFVARS=$(cat <<EOF
base_domain = "$BASE_DOMAIN"
domain_prefix = "$SUB_NAME"
resource_group_name = "$AZ_RESOURCE_GROUP"
az_subscription_id = "$AZ_SUBSCRIPTION_ID"
az_tenant_id = "$AZ_TENANT_ID"
az_client_id = "$AZ_CLIENT_ID"
az_client_secret = "$AZ_CLIENT_SECRET"
EOF
)

DNS_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-dns
next_pipeline_name: create-cluster
next_plan_name: terraform-plan
terraform_module: $IAAS/dns
azure_storage_bucket_folder: $IAAS/dns
EOF
)

CERTMGR_TFVARS=$(cat <<EOF
az_subscription_id = "$AZ_SUBSCRIPTION_ID"
az_tenant_id = "$AZ_TENANT_ID"
az_client_id = "$AZ_CLIENT_ID"
az_client_secret = "$AZ_CLIENT_SECRET"
cluster_issuer_resource_group = "$AZ_RESOURCE_GROUP"
domain = "$SUB_DOMAIN"
acme_email = "$EMAIL_ADDRESS"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

CERTMGR_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-certmanager
next_pipeline_name: install-nginx-ingress-controller
next_plan_name: terraform-plan
terraform_module: $IAAS/certmanager
azure_storage_bucket_folder: $IAAS/certmanager
EOF
)

EXTERNAL_DNS_TFVARS=$(cat <<EOF
domain_filter = "$SUB_DOMAIN"
resource_group_name = "$AZ_RESOURCE_GROUP"
az_subscription_id = "$AZ_SUBSCRIPTION_ID"
az_tenant_id = "$AZ_TENANT_ID"
az_client_id = "$AZ_CLIENT_ID"
az_client_secret = "$AZ_CLIENT_SECRET"
kubeconfig_path = "/tmp/build/put/kubeconfig/config"
EOF
)

EXTERNAL_DNS_CI_CONFIG=$(cat <<EOF
current_pipeline_name: install-external-dns
next_pipeline_name: install-harbor
next_plan_name: terraform-plan
terraform_module: $IAAS/external-dns
azure_storage_bucket_folder: $IAAS/external-dns
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
azure_storage_bucket_folder: k8s/harbor
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
azure_storage_bucket_folder: k8s/nginx-ingress-controller
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
product_version: $TAS4K8S_VERSION
bby_image: pacphi/bby
tanzu_network_api_token: $TANZU_NETWORK_API_TOKEN
scripts_repo_branch: master
azure_storage_bucket_folder: harbor
registry_password_tfvar_name: harbor_admin_password
EOF
)

ACME_TFVARS=$(cat <<EOF
base_domain = "$SUB_DOMAIN"
email = "$EMAIL_ADDRESS"
storage_account_name = "$AZ_STORAGE_ACCOUNT_NAME"
subscription_id = "$AZ_SUBSCRIPTION_ID"
tenant_id = "$AZ_TENANT_ID"
client_id = "$AZ_CLIENT_ID"
client_secret = "$AZ_CLIENT_SECRET"
resource_group_name = "$AZ_RESOURCE_GROUP"
path_to_certs_and_keys = "$CONCOURSE_TEAM/terraform/k8s/tas4k8s/certs-and-keys.vars"
uid = "$SUFFIX"
EOF
)

fi


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
if [ "$IAAS" == "tkg/azure"] || [ "$IAAS" == "tkg/aws"]; then
  fly -t $CONCOURSE_ALIAS set-pipeline -p create-management-cluster -c ./pipelines/$IAAS/linkable-terraform-mgmt-cluster.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/create-mgmt-cluster.yml --team=$CONCOURSE_TEAM --non-interactive
  fly -t $CONCOURSE_ALIAS set-pipeline -p create-workload-cluster -c ./pipelines/$IAAS/linkable-terraform-workload-cluster.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/create-workload-cluster.yml --team=$CONCOURSE_TEAM --non-interactive
  TKG_IAAS="$(cut -d'/' -f2 <<<"$IAAS")"
  IAAS=$TKG_IAAS
else
  fly -t $CONCOURSE_ALIAS set-pipeline -p create-cluster -c ./pipelines/$IAAS/linkable-cluster.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/create-cluster.yml --team=$CONCOURSE_TEAM --non-interactive
fi

fly -t $CONCOURSE_ALIAS set-pipeline -p create-dns -c ./pipelines/$IAAS/linkable-terraformer.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/create-dns.yml --team=$CONCOURSE_TEAM --non-interactive

if [ "$IAAS" == "aws"]; then
  fly -t $CONCOURSE_ALIAS set-pipeline -p install-certmanager -c ./pipelines/$IAAS/zone-aware-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/install-certmanager.yml --team=$CONCOURSE_TEAM --non-interactive
else
  fly -t $CONCOURSE_ALIAS set-pipeline -p install-certmanager -c ./pipelines/$IAAS/linkable-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/install-certmanager.yml --team=$CONCOURSE_TEAM --non-interactive
fi

fly -t $CONCOURSE_ALIAS set-pipeline -p install-nginx-ingress-controller -c ./pipelines/$IAAS/linkable-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/install-nginx-ingress-controller.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-external-dns -c ./pipelines/$IAAS/linkable-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/install-external-dns.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-harbor -c ./pipelines/$IAAS/linkable-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/install-harbor.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-tas4k8s -c ./pipelines/$IAAS/linkable-tas4k8s.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/install-tas4k8s.yml --team=$CONCOURSE_TEAM --non-interactive

# Log in again targeting team
fly -t $CONCOURSE_ALIAS login --concourse-url $CONCOURSE_ENDPOINT -u $CONCOURSE_ADMIN_USERNAME -p $CONCOURSE_ADMIN_PASSWORD --team-name=$CONCOURSE_TEAM

# Kick off first pipeline
fly -t $CONCOURSE_ALIAS unpause-pipeline -p create-dns