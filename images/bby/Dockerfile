FROM alpine:3.12 
LABEL author=cphillipson@pivotal.io

ENV BOSH_VERSION=6.4.1 \
    YTT_VERSION=0.30.0

RUN apk add --no-cache bash gawk sed grep bc coreutils && \
    wget -O bosh https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${BOSH_VERSION}-linux-amd64 && \
    chmod +x bosh && \
    mv bosh /usr/local/bin && \
    wget -O ytt https://github.com/k14s/ytt/releases/download/v${YTT_VERSION}/ytt-linux-amd64 && \
    chmod +x ytt && \
    mv ytt /usr/local/bin
