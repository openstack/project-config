#!/bin/bash

DOCKER=docker
SCRIPT_PATH=$(readlink -f $0)
GRAFYAML_DIR=$(dirname $SCRIPT_PATH)
SECRETS_DIR=${GRAFYAML_DIR}/grafana-secrets

if [ ! -d ${SECRETS_DIR} ]; then
    mkdir -p ${SECRETS_DIR}
    echo "password" > ${SECRETS_DIR}/admin_password
    echo "admin" > ${SECRETS_DIR}/admin_user
    echo "key" > ${SECRETS_DIR}/secret_key

fi

if [[ $(${DOCKER} ps -f "name=grafana-opendev_test" --format '{{.Names}}') \
        != 'grafana-opendev_test' ]]; then

    echo "Running Grafana"

    ${DOCKER} run -d --rm \
            --name grafana-opendev_test \
            -p 3000:3000 \
            -v ${SECRETS_DIR}:/etc/grafana/secrets \
            -e GF_AUTH_ANONYMOUS_ENABLED=true \
            -e GF_USER_ALLOW_SIGN_UP=false \
            -e GF_SECURITY_ADMIN_PASSWORD__FILE=/etc/grafana/secrets/admin_password \
            -e GF_SECURITY_ADMIN_USER__FILE=/etc/grafana/secrets/admin_user \
            -e GF_SECURITY_SECRET_KEY__FILE=/etc/grafana/secrets/secret_key \
            docker.io/grafana/grafana-oss

    echo "Grafana listening on :3000"
    echo "Waiting for startup ..."
    sleep 5
    echo " ... done"
fi

echo "Reloading dashboards"

${DOCKER} run --rm --network=host \
          -e 'GRAFANA_URL=http://admin:password@localhost:3000' \
          -v ${GRAFYAML_DIR}:/grafana:ro \
          opendevorg/grafyaml
