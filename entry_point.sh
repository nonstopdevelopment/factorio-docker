#!/bin/sh
cd /opt/factorio

whoami

echo "I am root" && id

jq '.username = env.FACTORIO_USERNAME | .password = env.FACTORIO_PASSWORD | .name = env.FACTORIO_SERVER_NAME | .description = env.FACTORIO_SERVER_DESCRIPTION' server-settings-template.json > server-settings.json

cat server-settings.json

whoami 
nohup /opt/factorio/bin/x64/factorio --start-server-load-latest --server-settings server-settings.json 

bash -c "while true; do sleep 1; done"
