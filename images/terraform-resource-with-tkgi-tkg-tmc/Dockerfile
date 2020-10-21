FROM alpine:3.12 as build

ARG vmw_username 
ARG vmw_password
ARG tanzu_network_api_token

ENV PIVNET_VERSION=2.0.1 \
    TMC_VERSION=0.2.0-f783ab07 \
    TKG_VERSION=1.2.0-vmware.1 \
    VMWUSER=$vmw_username \
    VMWPASS=$vmw_password \
    TANZU_NETWORK_API_TOKEN=$tanzu_network_api_token

RUN apk add --no-cache bash gawk sed grep bc coreutils npm && \
    npm install vmw-cli --global && \
    apk del --purge && \
    wget -O pivnet https://github.com/pivotal-cf/pivnet-cli/releases/download/v${PIVNET_VERSION}/pivnet-linux-amd64-${PIVNET_VERSION} && \
    chmod +x pivnet && \
    mv pivnet /usr/local/bin && \
    pivnet login --api-token=$TANZU_NETWORK_API_TOKEN && \
    pivnet download-product-files --product-slug='pivotal-container-service' --release-version='1.9.0' --product-file-id=795767 && \
    mv tkgi-linux-amd64-1.9.0-build.249 tkgi && \
    chmod +x tkgi && \
    mv tkgi /usr/local/bin && \
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
COPY --from=build /usr/local/bin/tkgi /usr/local/bin
COPY --from=build /usr/local/bin/tmc /usr/local/bin
