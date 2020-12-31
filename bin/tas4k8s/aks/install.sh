#!/usr/bin/env bash

# Create Terraform module variable file and Concourse pipeline configuration file content

COMMON_CI_CONFIG=$(cat <<EOF
uid: $SUFFIX
concourse_url: $CONCOURSE_URL
concourse_username: $CONCOURSE_ADMIN_USERNAME
concourse_password: $CONCOURSE_ADMIN_PASSWORD
concourse_team_name: $CONCOURSE_TEAM
concourse_is_insecure: $IS_CONCOURSE_INSECURE
concourse_is_in_debug_mode: $IS_CONCOURSE_IN_DEBUG_MODE
terraform_resource_with_carvel_image: $CARVEL_IMAGE
registry_username: $CONTAINER_REGISTRY_USERNAME
registry_password: $CONTAINER_REGISTRY_PASSWORD
pipeline_repo: $TF4K8S_PIPELINE_REPO
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
bby_image: $BBY_IMAGE
tanzu_network_api_token: $TANZU_NETWORK_API_TOKEN
scripts_repo: $TF4K8S_SCRIPTS_REPO
scripts_repo_branch: $TF4K8S_SCRIPTS_REPO_BRANCH
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

mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tas4k8s-bundles/$CONCOURSE_TEAM
touch $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tas4k8s-bundles/$CONCOURSE_TEAM/tas4k8s.tar.gz

echo -e "$COMMON_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/common.yml
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

# Create SSH public key
ssh-keygen -m PEM -t rsa -b 4096 -f $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/s3cr3ts/$CONCOURSE_TEAM/az_rsa -C ubuntu -P $AZ_CLIENT_SECRET

# Sync local config directory to bucket
rclone sync $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config $RCLONE_ALIAS:tf4k8s-pipelines-config-$SUFFIX --auto-confirm
rclone sync $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/s3cr3ts $RCLONE_ALIAS:s3cr3ts-$SUFFIX --auto-confirm
rclone sync $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tas4k8s-bundles $RCLONE_ALIAS:tas4k8s-bundles-$SUFFIX --auto-confirm

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