#!/usr/bin/env bash

# Launches a local instance of Concourse using BOSH and Virtualbox

## You must be running a verison of Virtualbox < 6.1
## @see https://github.com/cloudfoundry/bosh-deployment/issues/378
mkdir -p .concourse-local
git clone https://github.com/concourse/concourse-bosh-deployment.git .concourse-local
cd .concourse-local/lite
bosh create-env concourse.yml \
  -o ./infrastructures/virtualbox.yml \
  -l ../versions.yml \
  --vars-store vbox-creds.yml \
  --state vbox-state.json \
  -v internal_cidr=192.168.100.0/24 \
  -v internal_gw=192.168.100.1 \
  -v internal_ip=192.168.100.4 \
  -v public_ip=192.168.100.4
