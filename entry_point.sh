#!/bin/sh
cd /factorio/factorio

jq '.username = env.FACTORIO_USERNAME | .password = env.FACTORIO_PASSWORD | .name = env.FACTORIO_SERVER_NAME | .description = env.FACTORIO_SERVER_DESCRIPTION' server-settings-template.json > server-settings.json

nohup /factorio/factorio/bin/x64/factorio --start-server-load-latest --server-settings server-settings.json 
