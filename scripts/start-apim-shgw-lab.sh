#!/usr/bin/env bash
set -euo pipefail

: "${APIM_SUBSCRIPTION_ID:?Set APIM_SUBSCRIPTION_ID}"
: "${APIM_RESOURCE_GROUP:?Set APIM_RESOURCE_GROUP}"
: "${APIM_SERVICE_NAME:?Set APIM_SERVICE_NAME}"
: "${APIM_GATEWAY_NAME:?Set APIM_GATEWAY_NAME}"

gateway_image="${APIM_GATEWAY_IMAGE:-mcr.microsoft.com/azure-api-management/gateway:2.9.2}"
user_home="${HOME:-$(getent passwd "$(id -u)" | cut -d: -f6)}"
config_dir="${APIM_GATEWAY_CONFIG_DIR:-$user_home/.config/apim-shgw-lab}"
container_name="${APIM_GATEWAY_CONTAINER_NAME:-apim-shgw-lab}"
listen_ip="${APIM_GATEWAY_LISTEN_IP:-172.16.1.5}"
docker_network="${APIM_GATEWAY_DOCKER_NETWORK:-apim-shgw-lab}"

umask 077
mkdir -p "$config_dir"

arm_token_response=$(curl -fsS -H Metadata:true \
  "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fmanagement.azure.com%2F")
arm_token=$(printf '%s' "$arm_token_response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["access_token"])')
expiry=$(date -u -d '+29 days' '+%Y-%m-%dT%H:%M:%SZ')
token_url="https://management.azure.com/subscriptions/${APIM_SUBSCRIPTION_ID}/resourceGroups/${APIM_RESOURCE_GROUP}/providers/Microsoft.ApiManagement/service/${APIM_SERVICE_NAME}/gateways/${APIM_GATEWAY_NAME}/generateToken?api-version=2022-08-01"
request_body=$(printf '{"keyType":"primary","expiry":"%s"}' "$expiry")
gateway_token_response=$(curl -fsS -X POST \
  -H "Authorization: Bearer $arm_token" \
  -H 'Content-Type: application/json' \
  --data "$request_body" \
  "$token_url")
gateway_token_value=$(printf '%s' "$gateway_token_response" | python3 -c 'import json,sys; print(json.load(sys.stdin)["value"])')
gateway_token="GatewayKey ${gateway_token_value}"

cat >"$config_dir/env.conf" <<EOF
config.service.endpoint=https://${APIM_SERVICE_NAME}.configuration.azure-api.net
config.service.auth=${gateway_token}
EOF
chmod 600 "$config_dir/env.conf"

docker pull "$gateway_image" >/dev/null
docker network create "$docker_network" >/dev/null 2>&1 || true
docker rm -f "$container_name" >/dev/null 2>&1 || true
docker run -d \
  --name "$container_name" \
  --network "$docker_network" \
  --restart unless-stopped \
  --memory 1g \
  --cpus 0.75 \
  --env-file "$config_dir/env.conf" \
  -p "${listen_ip}:9080:8080" \
  -p "${listen_ip}:9081:8081" \
  "$gateway_image" >/dev/null

unset arm_token gateway_token gateway_token_value arm_token_response gateway_token_response
echo "Started ${container_name} on ${listen_ip}:9080 and ${listen_ip}:9081"