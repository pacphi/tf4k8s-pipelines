FROM ljfranklin/terraform-resource
LABEL author=cphillipson@pivotal.io

ENV KAPP_VERSION=0.34.0 \
    KBLD_VERSION=0.24.0 \
    TF_K14S_PLUGIN_VERSION=0.6.0 \
    VENDIR_VERSION=0.9.0 \
    YTT_VERSION=0.30.0

RUN apk add curl && \
    curl -LO "https://github.com/k14s/terraform-provider-k14s/releases/download/v${TF_K14S_PLUGIN_VERSION}/terraform-provider-k14s-binaries.tgz" && \
    tar xzvf terraform-provider-k14s-binaries.tgz -C /usr/local/share/terraform/plugins/ && \
    rm -Rf terraform-provider-k14s-binaries.tgz && \
    wget -O ytt https://github.com/k14s/ytt/releases/download/v${YTT_VERSION}/ytt-linux-amd64 && \
    chmod +x ytt && \
    mv ytt /usr/local/bin && \
    wget -O vendir https://github.com/k14s/vendir/releases/download/v${VENDIR_VERSION}/vendir-linux-amd64 && \
    chmod +x vendir && \
    mv vendir /usr/local/bin && \
    wget -O kapp https://github.com/k14s/kapp/releases/download/v${KAPP_VERSION}/kapp-linux-amd64 && \
    chmod +x kapp && \
    mv kapp /usr/local/bin && \
    wget -O kbld https://github.com/k14s/kbld/releases/download/v${KBLD_VERSION}/kbld-linux-amd64 && \
    chmod +x kbld && \
    mv kbld /usr/local/bin
