#!/usr/bin/env bash

# Tears down an existing remote instance of Concourse in Google Cloud Platform with Engineer Better's Control Tower CLI
## @see https://github.com/EngineerBetter/control-tower

if [ -z "$1" ] && [ -z "$2" ]; then
	echo "Usage: teardown-concourse-instance-on-gcp-with-control-tower.sh {path_to_google_credentials_json_file} {gcp_region}"
    echo "For example: ./teardown-concourse-instance-on-gcp-with-control-tower.sh ~/.tf4k8s/gcp/tf4k8s-sa.foo.json us-west1"
	exit 1
fi

PATH_TO_CREDENTIALS="$1"
REGION="$2"

export GOOGLE_APPLICATION_CREDENTIALS=$PATH_TO_CREDENTIALS
control-tower destroy --iaas gcp --region $REGION concourse
