#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Use environment variables defined in Dockerfile or overridden at runtime
# FACTORIO_DIR=/factorio/factorio (from Dockerfile)
# FACTORIO_CONFIG_DIR=${FACTORIO_DIR}/config (from Dockerfile)
# FACTORIO_SAVES_DIR=${FACTORIO_DIR}/saves (from Dockerfile)

cd "${FACTORIO_DIR}"

echo "Running as user: $(whoami) (ID: $(id -u))"
echo "Working directory: $(pwd)"

# Test permissions (optional but good for debugging)
echo "Attempting to write to .: $(touch ./test_write && rm ./test_write && echo OK || echo FAILED)"
echo "Attempting to write to saves: $(touch ${FACTORIO_SAVES_DIR}/test_write && rm ${FACTORIO_SAVES_DIR}/test_write && echo OK || echo FAILED)"
echo "Attempting to write to config: $(touch ${FACTORIO_CONFIG_DIR}/test_write && rm ${FACTORIO_CONFIG_DIR}/test_write && echo OK || echo FAILED)"


# Define the target path for server settings within the config volume
SERVER_SETTINGS_PATH="${FACTORIO_CONFIG_DIR}/server-settings.json"
MAP_GEN_SETTINGS_PATH="${FACTORIO_CONFIG_DIR}/map-gen-settings.json" # Example for other configs
MAP_SETTINGS_PATH="${FACTORIO_CONFIG_DIR}/map-settings.json"       # Example for other configs


# Check if server-settings.json already exists IN THE CONFIG DIR
if [ ! -f "${SERVER_SETTINGS_PATH}" ]; then
  # Make sure the template file exists before trying to use it
  if [ ! -f "server-settings-template.json" ]; then
      echo "ERROR: server-settings-template.json not found in ${PWD}!"
      exit 1
  fi
  echo "Generating ${SERVER_SETTINGS_PATH} from template..."
  # Write the generated settings to the CONFIG directory
  jq '.username = env.FACTORIO_USERNAME | .password = env.FACTORIO_PASSWORD | .name = env.FACTORIO_SERVER_NAME | .description = env.FACTORIO_SERVER_DESCRIPTION' \
     server-settings-template.json > "${SERVER_SETTINGS_PATH}"
else
  echo "Using existing ${SERVER_SETTINGS_PATH}."
  # Optionally: Update specific fields if needed from ENV vars even if file exists
  # jq --arg user "$FACTORIO_USERNAME" --arg pass "$FACTORIO_PASSWORD" '.username = $user | .password = $pass' "${SERVER_SETTINGS_PATH}" > tmp.$$.json && mv tmp.$$.json "${SERVER_SETTINGS_PATH}"
fi

# --- Add similar logic for map-gen-settings.json and map-settings.json if needed ---
# Example: Copy defaults if they don't exist in the config volume
# if [ ! -f "${MAP_GEN_SETTINGS_PATH}" ]; then
#   echo "Copying default map-gen-settings.json to config volume..."
#   cp data/map-gen-settings.json "${MAP_GEN_SETTINGS_PATH}"
# fi
# if [ ! -f "${MAP_SETTINGS_PATH}" ]; then
#   echo "Copying default map-settings.json to config volume..."
#   cp data/map-settings.json "${MAP_SETTINGS_PATH}"
# fi


echo "Starting Factorio server..."

# Use exec to replace the shell process with the Factorio process
# Point the server to use the settings file FROM THE CONFIG DIRECTORY
# Also point to other config files in the config directory if you manage them
exec ./bin/x64/factorio \
  --start-server-load-latest \
  --server-settings "${SERVER_SETTINGS_PATH}" \
  --map-gen-settings "${MAP_GEN_SETTINGS_PATH}" \
  --map-settings "${MAP_SETTINGS_PATH}" \
  "$@" # Pass any extra arguments from Kubernetes args/command

# The script will not reach here if exec is successful
echo "Factorio server exited."
exit 1