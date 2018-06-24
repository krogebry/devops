#!/bin/bash

$(curl -k -H "X-Vault-Token: ${VAULT_AUTH_TOKEN} " \
  -X GET ${VAULT_URL}/v1/secret/dev/wt-api | jq '.data| to_entries|map("export \(.key)=\(.value|tostring)")|.[]'|sed 's/"//g')

/opt/wt/bin/wt-api $@
