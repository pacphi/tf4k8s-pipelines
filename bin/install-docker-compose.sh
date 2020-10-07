#!/bin/bash

# This script installs docker-compose binary on Ubuntu distributions

DOCKER_COMPOSE_VERSION=1.27.4
sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose