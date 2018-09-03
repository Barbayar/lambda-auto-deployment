#!/usr/bin/env bash

set -e

pushd $(dirname ${0})

if [ "$#" -ne 1 ]; then
    echo "usage: ${0} ACCOUNT_ID"

    exit 1
fi

ACCOUNT=${1}

pushd ${ACCOUNT}

REGIONS=$(ls)

for REGION in ${REGIONS}; do
    pushd ${REGION}

    aws lambda list-functions --region ${REGION} --output text --query 'Functions[*].[FunctionName, CodeSha256]' > /tmp/${REGION}.lst
    FUNCTIONS=$(ls)

    for FUNCTION in ${FUNCTIONS}; do
        pushd ${FUNCTION}

        rm /tmp/${FUNCTION}.zip || true
        find . -exec touch -amt 201808080000.00 {} + # changes access and modification time to a fixed value to reproduce exactly same zip file
        zip -X --recurse-paths --quiet /tmp/${FUNCTION}.zip .
        SHA256=$(openssl dgst -sha256 -binary /tmp/${FUNCTION}.zip | openssl enc -base64)

        if grep "${FUNCTION}" /tmp/${REGION}.lst | grep -q "${SHA256}"; then
            echo "${FUNCTION}: SHA256 checksum is same, won't deploy"
        else
            echo "${FUNCTION}: deploying..."
            aws lambda update-function-code --region ${REGION} --function-name ${FUNCTION} --zip-file fileb:///tmp/${FUNCTION}.zip
            echo "${FUNCTION}: deployed"
        fi

        popd
    done

    popd
done

popd
popd
