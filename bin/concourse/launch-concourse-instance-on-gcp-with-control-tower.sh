#!/usr/bin/env bash

# Launches a remote instance of Concourse in Google Cloud Platform with Engineer Better's Control Tower CLI
## @see https://github.com/EngineerBetter/control-tower

if [ -z "$1" ] && [ -z "$2" ] && [ -z "$3" ]; then
	echo "Usage: launch-concourse-instance-on-gcp-with-control-tower.sh {path_to_google_credentials_json_file} {gcp_region} {domain}"
    echo "For example: ./launch-concourse-instance-on-gcp-with-control-tower.sh ~/.tf4k8s/gcp/tf4k8s-sa.foo.json us-west1 foo.me"
	exit 1
fi

PATH_TO_CREDENTIALS="$1"
REGION="$2"
DOMAIN="$3"

export GOOGLE_APPLICATION_CREDENTIALS=$PATH_TO_CREDENTIALS
control-tower deploy --iaas gcp --region $REGION --domain concourse.$DOMAIN concourse
