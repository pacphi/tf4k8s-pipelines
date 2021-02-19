FROM ljfranklin/terraform-resource:0.14.7
LABEL author=cphillipson@pivotal.io

RUN apk --no-cache add curl python3 python3-dev py3-pip && \
    apk --no-cache add --virtual=build gcc libffi-dev musl-dev openssl-dev make && \
    pip3 --no-cache-dir install -U pip && \
    pip3 --no-cache-dir install azure-cli && \
    apk del --purge build