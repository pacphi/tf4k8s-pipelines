#!/bin/sh

CLI=/usr/bin/vmw-cli

FILES=$( ${CLI} ls ${PRODUCT_CATEGORY}/${PRODUCT_VERSION}/${PRODUCT_TYPE} | egrep ${PRODUCT_FILE_GLOB} | cut -d' ' -f1 )

for i in ${FILES}; do
  ${CLI} cp ${i}
  mv /files/${i} product
done