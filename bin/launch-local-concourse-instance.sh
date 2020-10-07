#!/bin/bash

# Launches a local instance of Concourse using Docker Compose

mkdir .concourse-local
git clone https://github.com/concourse/concourse-docker .concourse-local
cd .concourse-local
./keys/generate
docker-compose up -d
echo "Visit localhost:8080 with your favorite browser.  Login using credentials [ username: test, password: test ]."
