#!/usr/bin/env bash

# Create Terraform module variable file and Concourse pipeline configuration file content

CLOUD="$(cut -d'/' -f2 <<<"$IAAS")"

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
registry_username: $CONTAINER_REGISTRY_USERNAME
registry_password: $CONTAINER_REGISTRY_PASSWORD
pipeline_repo: $TF4K8S_PIPELINE_REPO
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
control_plane_machine_type = "$TKG_CONTROL_PLANE_MACHINE_TYPE"
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
terraform_module: $IAAS/mgmt
s3_bucket_folder: $IAAS/mgmt
tkg_plan: $TKG_PLAN
tkg_management_cluster_name: $TKG_MGMT_CLUSTER_NAME
vmw_username: $MY_VMWARE_USERNAME
vmw_password: $MY_VMWARE_PASSWORD
tkg_cli_gz: $TKG_CLI_GZ
EOF
)

WKLD_CLUSTER_CI_CONFIG=$(cat <<EOF
current_pipeline_name: create-workload-cluster
next_pipeline_name: install-certmanager
next_plan_name: terraform-plan
terraform_module: $IAAS/workload
s3_bucket_folder: $IAAS/workload
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
next_pipeline_name: create-management-cluster
next_plan_name: terraform-plan
terraform_module: $CLOUD/dns
s3_bucket_folder: $CLOUD/dns
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
terraform_module: $CLOUD/certmanager
s3_bucket_folder: $CLOUD/certmanager
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
terraform_module: $CLOUD/external-dns
s3_bucket_folder: $CLOUD/external-dns
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
bby_image: $BBY_IMAGE
tanzu_network_api_token: $TANZU_NETWORK_API_TOKEN
scripts_repo: $TF4K8S_SCRIPTS_REPO
scripts_repo_branch: $TF4K8S_SCRIPTS_REPO_BRANCH
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

# Place Terraform module variable files and Concourse pipeline configuration files
mkdir -p ci/$CONCOURSE_TEAM/$IAAS
mkdir -p ci/$CONCOURSE_TEAM/$CLOUD
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/mgmt
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/workload
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$CLOUD/dns
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$CLOUD/certmanager
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/nginx-ingress-controller
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$CLOUD/external-dns
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/harbor
mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/tas4k8s/acme

mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/s3cr3ts/$CONCOURSE_TEAM/.kube
touch $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/s3cr3ts/$CONCOURSE_TEAM/.kube/config

echo -e "$COMMON_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/common.yml
echo -e "$MGMT_CLUSTER_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/create-mgmt-cluster.yml
echo -e "$WKLD_CLUSTER_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$IAAS/create-workload-cluster.yml

echo -e "$DNS_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$CLOUD/create-dns.yml
echo -e "$CERTMGR_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$CLOUD/install-certmanager.yml
echo -e "$NIC_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$CLOUD/install-nginx-ingress-controller.yml
echo -e "$EXTERNAL_DNS_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$CLOUD/install-external-dns.yml
echo -e "$HARBOR_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$CLOUD/install-harbor.yml
echo -e "$TAS4K8S_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/$CLOUD/install-tas4k8s.yml

echo -e "$DNS_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$CLOUD/dns/terraform.tfvars
echo -e "$MGMT_CLUSTER_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/mgmt/terraform.tfvars
echo -e "$WKLD_CLUSTER_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$IAAS/workload/terraform.tfvars
echo -e "$CERTMGR_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$CLOUD/certmanager/terraform.tfvars
echo -e "$NIC_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/nginx-ingress-controller/terraform.tfvars
echo -e "$EXTERNAL_DNS_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/$CLOUD/external-dns/terraform.tfvars
echo -e "$HARBOR_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/harbor/terraform.tfvars
echo -e "$ACME_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/tas4k8s/acme/terraform.tfvars
echo -e "$TAS4K8S_TFVARS" > $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config/$CONCOURSE_TEAM/terraform/k8s/tas4k8s/terraform.tfvars

# Sync local config directory to bucket
rclone sync $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/tf4k8s-pipelines-config $RCLONE_ALIAS:tf4k8s-pipelines-config-$SUFFIX --auto-confirm
rclone sync $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/s3cr3ts $RCLONE_ALIAS:s3cr3ts-$SUFFIX --auto-confirm

if [ "$TKG_PIPELINE_DEF_SUFFIX" == "-v2"]; then
  mkdir -p $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/binaries/$CONCOURSE_TEAM/
  cp $PATH_TO_TKG_CLI_GZ $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/binaries/$CONCOURSE_TEAM/
  rclone mkdir $RCLONE_ALIAS:binaries-$SUFFIX
  rclone sync $HOME/$TF4K8S_PIPELINES_CONFIG_PARENT_DIR/binaries $RCLONE_ALIAS:binaries-$SUFFIX --auto-confirm
fi

# First login to Concourse instance
fly -t $CONCOURSE_ALIAS login --concourse-url $CONCOURSE_ENDPOINT -u $CONCOURSE_ADMIN_USERNAME -p $CONCOURSE_ADMIN_PASSWORD

# Create a new team
fly -t $CONCOURSE_ALIAS set-team --team-name $CONCOURSE_TEAM --local-user $CONCOURSE_ADMIN_USERNAME --non-interactive

# Set pipelines
fly -t $CONCOURSE_ALIAS set-pipeline -p create-dns -c ./pipelines/$CLOUD/linkable-terraformer.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$CLOUD/create-dns.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p create-management-cluster -c ./pipelines/$IAAS/linkable-terraform-mgmt-cluster$TKG_PIPELINE_DEF_SUFFIX.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/create-mgmt-cluster.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p create-workload-cluster -c ./pipelines/$IAAS/linkable-terraform-workload-cluster.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/create-workload-cluster.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-certmanager -c ./pipelines/$CLOUD/zone-aware-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$CLOUD/install-certmanager.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-nginx-ingress-controller -c ./pipelines/$CLOUD/linkable-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$CLOUD/install-nginx-ingress-controller.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-external-dns -c ./pipelines/$CLOUD/linkable-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$CLOUD/install-external-dns.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-harbor -c ./pipelines/$CLOUD/linkable-terraformer-with-carvel.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$CLOUD/install-harbor.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p install-tas4k8s -c ./pipelines/$CLOUD/linkable-tas4k8s.yml -l ./ci/$CONCOURSE_TEAM/$IAAS/common.yml -l ./ci/$CONCOURSE_TEAM/$CLOUD/install-tas4k8s.yml --team=$CONCOURSE_TEAM --non-interactive

# Log in again targeting team
fly -t $CONCOURSE_ALIAS login --concourse-url $CONCOURSE_ENDPOINT -u $CONCOURSE_ADMIN_USERNAME -p $CONCOURSE_ADMIN_PASSWORD --team-name=$CONCOURSE_TEAM

# Kick off first pipeline
fly -t $CONCOURSE_ALIAS unpause-pipeline -p create-dns