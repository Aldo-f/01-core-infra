#!/bin/bash
echo "Testing Traefik reload..."
docker exec traefik kill -HUP $(docker exec traefik traefik --file=/etc/traefik/routes.yml get --entryPoints.web.HTTP && echo $(pwd))