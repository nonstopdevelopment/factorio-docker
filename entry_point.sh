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


# Define paths for config files and the writable data directory WITHIN the config volume
SERVER_SETTINGS_PATH="${FACTORIO_CONFIG_DIR}/server-settings.json"
CONFIG_INI_PATH="${FACTORIO_CONFIG_DIR}/config.ini"
# Let's put runtime writable data (logs, lock file, player-data.json etc)
# in a subdirectory within the config volume for neatness & persistence.
WRITE_DATA_PATH="${FACTORIO_CONFIG_DIR}/runtime-data"
MAP_GEN_SETTINGS_PATH="${FACTORIO_CONFIG_DIR}/map-gen-settings.json" # Example for other configs
MAP_SETTINGS_PATH="${FACTORIO_CONFIG_DIR}/map-settings.json"       # Example for other configs

# --- Create Writable Data Directory ---
# This *must* exist before Factorio starts and tries to use it.
echo "Ensuring writable data directory exists: ${WRITE_DATA_PATH}"
mkdir -p "${WRITE_DATA_PATH}"


# --- Generate/Check config.ini ---
if [ ! -f "${CONFIG_INI_PATH}" ]; then
  echo "Generating ${CONFIG_INI_PATH}..."
  cat <<EOF > "${CONFIG_INI_PATH}"
[path]
read-data=/factorio/factorio/data
write-data=${WRITE_DATA_PATH}
EOF
else
  echo "Using existing ${CONFIG_INI_PATH}."
fi


# --- !!! ALWAYS Generate server-settings.json !!! ---
# Remove the check for existence. We will always overwrite it from ENV vars.
echo "Generating ${SERVER_SETTINGS_PATH} from template using current environment variables..."
# Make sure the template file exists before trying to use it
if [ ! -f "server-settings-template.json" ]; then
    echo "ERROR: server-settings-template.json not found in ${PWD}!"
    exit 1
fi
# Write the generated settings to the CONFIG directory, overwriting if it exists.
jq '.username = env.FACTORIO_USERNAME | .password = env.FACTORIO_PASSWORD | .name = env.FACTORIO_SERVER_NAME | .description = env.FACTORIO_SERVER_DESCRIPTION' \
   server-settings-template.json > "${SERVER_SETTINGS_PATH}"
# --- End of always generating server-settings.json ---

# --- !!! Output server-settings.json to console for debugging!!! ---
echo "Config output for validation:"
cat "${SERVER_SETTINGS_PATH}"
# --- !!! End settings debug !!! ---

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
# Add --config to tell Factorio to use our generated config.ini
# Point the server to use the settings file FROM THE CONFIG DIRECTORY
# Also point to other config files in the config directory if you manage them
exec ./bin/x64/factorio \
  --config "${CONFIG_INI_PATH}" \
  --server-settings "${SERVER_SETTINGS_PATH}" \
  --map-gen-settings "${MAP_GEN_SETTINGS_PATH}" \
  --map-settings "${MAP_SETTINGS_PATH}" \
  --start-server-load-latest \
  "$@" # Pass any extra arguments from Kubernetes args/command

# The script will not reach here if exec is successful
echo "Factorio server exited."
exit 1