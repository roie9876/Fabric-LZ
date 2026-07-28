#!/usr/bin/env bash
set -euo pipefail

backend_image="${APIM_ECHO_IMAGE:-hashicorp/http-echo:1.0}"
backend_name="${APIM_ECHO_CONTAINER_NAME:-apim-shgw-echo}"
docker_network="${APIM_GATEWAY_DOCKER_NETWORK:-apim-shgw-lab}"

docker network create "$docker_network" >/dev/null 2>&1 || true
docker pull "$backend_image" >/dev/null
docker rm -f "$backend_name" >/dev/null 2>&1 || true
docker run -d \
  --name "$backend_name" \
  --network "$docker_network" \
  --restart unless-stopped \
  --memory 64m \
  --cpus 0.10 \
  "$backend_image" \
  -listen=:8080 \
  -text=apim-self-hosted-gateway-ok >/dev/null

echo "Started ${backend_name} on the private ${docker_network} Docker network"