FROM alpine:3.12 as build

ARG vmw_username 
ARG vmw_password

ENV TMC_VERSION=0.2.0-fbbe4ca1 \
    TKG_VERSION=1.2.0-vmware.1 \
    VMWUSER=$vmw_username \
    VMWPASS=$vmw_password \
    TANZU_NETWORK_API_TOKEN=$tanzu_network_api_token

RUN apk add --no-cache bash gawk sed grep bc coreutils npm && \
    npm install vmw-cli --global && \
    apk del --purge && \
    wget -O tmc https://vmware.bintray.com/tmc/${TMC_VERSION}/linux/x64/tmc && \
    chmod +x tmc && \
    mv tmc /usr/local/bin && \
    vmw-cli ls vmware_tanzu_kubernetes_grid && \
    vmw-cli cp tkg-linux-amd64-v${TKG_VERSION}.tar.gz && \
    tar xvf tkg-linux-amd64-v${TKG_VERSION}.tar.gz && \
    cd tkg && \
    mv tkg-linux-amd64* tkg && \
    chmod +x tkg && \
    mv tkg /usr/local/bin && \
    cd .. && \
    rm -Rf tkg

FROM ljfranklin/terraform-resource:0.13.4
LABEL author=cphillipson@pivotal.io

COPY --from=build /usr/local/bin/tkg /usr/local/bin
COPY --from=build /usr/local/bin/tmc /usr/local/bin
