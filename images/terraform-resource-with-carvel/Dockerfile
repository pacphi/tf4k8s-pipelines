FROM alpine:3.12 as build

ENV AWS_IAM_AUTHENTICATOR_VERSION="1.18.8/2020-09-18" \
    BOSH_VERSION=6.4.1 \
    KAPP_VERSION=0.34.0 \
    KBLD_VERSION=0.27.0 \
    VENDIR_VERSION=0.10.0 \
    YTT_VERSION=0.30.0

RUN mkdir -p /opt/downloads && \
    apk --no-cache add curl && \
    wget -O bosh https://s3.amazonaws.com/bosh-cli-artifacts/bosh-cli-${BOSH_VERSION}-linux-amd64 && \
    chmod +x bosh && \
    mv bosh /opt/downloads && \
    curl -o aws-iam-authenticator "https://amazon-eks.s3.us-west-2.amazonaws.com/${AWS_IAM_AUTHENTICATOR_VERSION}/bin/linux/amd64/aws-iam-authenticator" && \
    chmod +x aws-iam-authenticator && \
    mv aws-iam-authenticator /opt/downloads && \
    wget -O ytt https://github.com/k14s/ytt/releases/download/v${YTT_VERSION}/ytt-linux-amd64 && \
    chmod +x ytt && \
    mv ytt /opt/downloads && \
    wget -O vendir https://github.com/k14s/vendir/releases/download/v${VENDIR_VERSION}/vendir-linux-amd64 && \
    chmod +x vendir && \
    mv vendir /opt/downloads && \
    wget -O kapp https://github.com/k14s/kapp/releases/download/v${KAPP_VERSION}/kapp-linux-amd64 && \
    chmod +x kapp && \
    mv kapp /opt/downloads && \
    wget -O kbld https://github.com/k14s/kbld/releases/download/v${KBLD_VERSION}/kbld-linux-amd64 && \
    chmod +x kbld && \
    mv kbld /opt/downloads

FROM ljfranklin/terraform-resource:0.13.4
LABEL author=cphillipson@pivotal.io

ENV TF_PLUGIN_DIR=".terraform.d/plugins" \
    TF_K14S_PLUGIN_VERSION=0.6.0

COPY --from=build /opt/downloads/* /usr/local/bin/

RUN apk --no-cache add curl python3 python3-dev py3-pip && \
    apk --no-cache add --virtual=build gcc libffi-dev musl-dev openssl-dev make && \
    pip3 --no-cache-dir install -U pip && \
    pip3 --no-cache-dir install azure-cli && \
    apk del --purge build && \
    mkdir -p $HOME/$TF_PLUGIN_DIR/registry.terraform.io/hashicorp/k14s/$TF_K14S_PLUGIN_VERSION && \
    curl -LO "https://github.com/k14s/terraform-provider-k14s/releases/download/v${TF_K14S_PLUGIN_VERSION}/terraform-provider-k14s-binaries.tgz" && \
    tar xzvf terraform-provider-k14s-binaries.tgz -C $HOME/$TF_PLUGIN_DIR/registry.terraform.io/hashicorp/k14s/$TF_K14S_PLUGIN_VERSION && \
    rm -Rf terraform-provider-k14s-binaries.tgz
