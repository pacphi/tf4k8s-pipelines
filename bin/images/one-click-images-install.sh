#!/usr/bin/env bash

# tf4k8s-pipelines One-click Container Images Build and Publish Script
# @author Chris Phillipson
# @version 1.0

source $PWD/bin/images/one-click-images-config.sh

# Set Concourse endpoint
CONCOURSE_ENDPOINT=$CONCOURSE_URL
if [ "$CONCOURSE_URL" == "http://web:8080" ] || [ -z $CONCOURSE_URL ]; then
  CONCOURSE_ENDPOINT="http://localhost:8080"
fi

# First login to Concourse instance
fly -t $CONCOURSE_ALIAS login --concourse-url $CONCOURSE_ENDPOINT -u $CONCOURSE_ADMIN_USERNAME -p $CONCOURSE_ADMIN_PASSWORD

# Create a new team
fly -t $CONCOURSE_ALIAS set-team --team-name $CONCOURSE_TEAM --local-user $CONCOURSE_ADMIN_USERNAME --non-interactive

# Seed Concourse configuration
COMMON_CI_CONFIG=$(cat <<EOF
pipeline_repo: $TF4K8S_PIPELINE_REPO
pipeline_repo_branch: $TF4K8S_PIPELINE_REPO_BRANCH
vmw_username: $MY_VMWARE_USERNAME
vmw_password: $MY_VMWARE_PASSWORD
registry-username: $CONTAINER_REGISTRY_USERNAME
registry-password: $CONTAINER_REGISTRY_PASSWORD
image-repo-name: $CONTAINER_IMAGE_REPO_NAME
EOF
)
mkdir -p ci/$CONCOURSE_TEAM
echo -e "$COMMON_CI_CONFIG" > $PWD/ci/$CONCOURSE_TEAM/common.yml

# Set pipelines
fly -t $CONCOURSE_ALIAS set-pipeline -p build-and-push-bash-bosh-and-ytt-image -c ./pipelines/build-and-push-bash-bosh-and-ytt-image.yml -l ./ci/$CONCOURSE_TEAM/common.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p build-and-push-terraform-resource-with-az-cli-image -c ./pipelines/build-and-push-terraform-resource-with-az-cli-image.yml -l ./ci/$CONCOURSE_TEAM/common.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p build-and-push-terraform-resource-with-carvel-image -c ./pipelines/build-and-push-terraform-resource-with-carvel-image.yml -l ./ci/$CONCOURSE_TEAM/common.yml --team=$CONCOURSE_TEAM --non-interactive
fly -t $CONCOURSE_ALIAS set-pipeline -p build-and-push-terraform-resource-with-tkg-tmc-image -c ./pipelines/build-and-push-terraform-resource-with-tkg-tmc-image.yml -l ./ci/$CONCOURSE_TEAM/common.yml --team=$CONCOURSE_TEAM --non-interactive
