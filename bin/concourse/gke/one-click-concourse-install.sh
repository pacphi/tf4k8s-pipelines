#!/usr/bin/env bash

source $PWD/bin/concourse/gke/one-click-concourse-config.sh

# Utilize Terraform modules in tf4k8s to provision a GKE cluster, install foundational components, and bring up a Concourse instance
## Prerequisites: Google Cloud Platform account credentials, git, gcloud, kubectl, helm, kapp, kbld, terraform, ytt

CLUSTER_TFVARS=$(cat <<EOF
gcp_project = "$GCP_PROJECT"
gcp_region = "$GCP_REGION"
gke_name = "$K8S_ENV"
gke_nodes = $GKE_NODES
gke_preemptible = false
gke_node_type = "$GKE_NODE_TYPE"
gcp_service_account_credentials = "$GOOGLE_APPLICATION_CREDENTIALS"
EOF
)

DNS_TFVARS=$(cat <<EOF
project = "$GCP_PROJECT"
root_zone_name = "$BASE_NAME-zone"
environment_name = "$SUB_NAME"
dns_prefix = "$SUB_NAME"
gcp_service_account_credentials = "$GOOGLE_APPLICATION_CREDENTIALS"
EOF
)

CERTMGR_TFVARS=$(cat <<EOF
project = "$GCP_PROJECT"
domain = "$SUB_DOMAIN"
acme_email = "$EMAIL_ADDRESS"
dns_zone_name = "$SUB_NAME-zone"
gcp_service_account_credentials = "$GOOGLE_APPLICATION_CREDENTIALS"
kubeconfig_path = "$HOME/.kube/config"
EOF
)

EXTERNAL_DNS_TFVARS=$(cat <<EOF
domain_filter = "$SUB_DOMAIN"
gcp_project = "$GCP_PROJECT"
gcp_service_account_credentials = "$GOOGLE_APPLICATION_CREDENTIALS"
kubeconfig_path = "$HOME/.kube/config"
EOF
)

CONCOURSE_TFVARS=$(cat <<EOF
domain = "$SUB_DOMAIN"
ingress = "nginx"
kubeconfig_path = "$HOME/.kube/config"
EOF
)

NIC_TFVARS=$(cat <<EOF
kubeconfig_path = "$HOME/.kube/config"
EOF
)

## Fetch tf4k8s
mkdir -p .concourse-local
git clone https://github.com/pacphi/tf4k8s.git .concourse-local
cd .concourse-local/experiments

# Write terraform.tfvars files
echo -e "$DNS_TFVARS" > $PWD/gcp/dns/terraform.tfvars
echo -e "$CLUSTER_TFVARS" > $PWD/gcp/cluster/terraform.tfvars
echo -e "$CERTMGR_TFVARS" > $PWD/gcp/certmanager/terraform.tfvars
echo -e "$NIC_TFVARS" > $PWD/k8s/nginx-ingress/terraform.tfvars
echo -e "$EXTERNAL_DNS_TFVARS" > $PWD/gcp/external-dns/terraform.tfvars
echo -e "$CONCOURSE_TFVARS" > $PWD/k8s/concourse/terraform.tfvars

# Create DNS Zone
cd gcp/dns
. $PWD/create-zone.sh

# Provision cluster
cd ../cluster
. $PWD/create-cluster.sh
cat $(terraform output path_to_kubeconfig | tr -d '"') > $HOME/.kube/config

# Install cert-manager
cd ../certmanager
. $PWD/create-certmanager.sh

# Install nginx-ingress-controller
cd ../../k8s/nginx-ingress
. $PWD/create-nginx-ingress.sh

# Install external-dns
cd ../../gcp/external-dns
. $PWD/create-external-dns.sh

# Install Concourse
cd ../../k8s/concourse
. $PWD/create-concourse.sh
