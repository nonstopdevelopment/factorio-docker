#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Use environment variables defined in Dockerfile or overridden at runtime
FACTORIO_DIR=/factorio/factorio
FACTORIO_CONFIG_DIR=${FACTORIO_DIR}/config
FACTORIO_SAVES_DIR=${FACTORIO_DIR}/saves # Still potentially used for volume mount point, even if Factorio doesn't save here directly now

cd "${FACTORIO_DIR}"

echo "Running as user: $(whoami) (ID: $(id -u))"
echo "Working directory: $(pwd)"

# Define paths
SERVER_SETTINGS_PATH="${FACTORIO_CONFIG_DIR}/server-settings.json"
CONFIG_INI_PATH="${FACTORIO_CONFIG_DIR}/config.ini"
WRITE_DATA_PATH="${FACTORIO_CONFIG_DIR}/runtime-data"
MAP_GEN_SETTINGS_PATH="${FACTORIO_CONFIG_DIR}/map-gen-settings.json"
MAP_SETTINGS_PATH="${FACTORIO_CONFIG_DIR}/map-settings.json"
# Define the specific directory where Factorio expects saves based on config.ini
SAVES_DIR_IN_WRITE_PATH="${WRITE_DATA_PATH}/saves"

# --- Create Writable Data Directories ---
echo "Ensuring writable data directory exists: ${WRITE_DATA_PATH}"
mkdir -p "${WRITE_DATA_PATH}"
echo "Ensuring saves subdirectory exists within write-data: ${SAVES_DIR_IN_WRITE_PATH}"
mkdir -p "${SAVES_DIR_IN_WRITE_PATH}" # Creates /factorio/factorio/config/runtime-data/saves

# Test permissions (optional but good for debugging)
echo "Attempting to write to .: $(touch ./test_write && rm ./test_write && echo OK || echo FAILED)"
# Test the original saves mount point if it exists/is mounted
if [ -d "${FACTORIO_SAVES_DIR}" ]; then
    echo "Attempting to write to primary saves mount ${FACTORIO_SAVES_DIR}: $(touch ${FACTORIO_SAVES_DIR}/test_write && rm ${FACTORIO_SAVES_DIR}/test_write && echo OK || echo FAILED)"
fi
echo "Attempting to write to config mount ${FACTORIO_CONFIG_DIR}: $(touch ${FACTORIO_CONFIG_DIR}/test_write && rm ${FACTORIO_CONFIG_DIR}/test_write && echo OK || echo FAILED)"
# Test the actual directory Factorio will save to
echo "Attempting to write to effective saves dir ${SAVES_DIR_IN_WRITE_PATH}: $(touch ${SAVES_DIR_IN_WRITE_PATH}/test_write && rm ${SAVES_DIR_IN_WRITE_PATH}/test_write && echo OK || echo FAILED)"


# --- Generate/Check config.ini ---
# (Keep this section as it was - it correctly sets write-data)
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


# --- Generate server-settings.json ---
# (Keep this section as it was)
echo "Generating ${SERVER_SETTINGS_PATH} from template using current environment variables..."
if [ ! -f "server-settings-template.json" ]; then
    echo "ERROR: server-settings-template.json not found in ${PWD}!"
    exit 1
fi
jq '.username = env.FACTORIO_USERNAME | .password = env.FACTORIO_PASSWORD | .name = env.FACTORIO_SERVER_NAME | .description = env.FACTORIO_SERVER_DESCRIPTION' \
   server-settings-template.json > "${SERVER_SETTINGS_PATH}"

echo "Config output for validation:"
cat "${SERVER_SETTINGS_PATH}"


# --- Check for existing saves and determine start command ---
echo "Checking for existing saves in ${SAVES_DIR_IN_WRITE_PATH}..."
# Find the newest .zip file. Use find for safety with filenames. -maxdepth 1 avoids searching subdirs.
# Check if *any* zip file exists. We don't need the exact name here, just whether to use create or load.
LATEST_SAVE_EXISTS=$(find "${SAVES_DIR_IN_WRITE_PATH}" -maxdepth 1 -name '*.zip' -print -quit)

if [ -n "${LATEST_SAVE_EXISTS}" ]; then
  # Found at least one save file
  echo "Existing save(s) found. Starting server with --start-server-load-latest."
  FACTORIO_START_COMMAND="--start-server-load-latest"
else
  # No save files found - create a new one
  # Define a default save name for the first run (Factorio needs a filename for --create)
  # Using _autosave1 mimics Factorio's default naming convention
  FIRST_SAVE_NAME="${SAVES_DIR_IN_WRITE_PATH}/_autosave1.zip"
  echo "No existing saves found. Creating new map: ${FIRST_SAVE_NAME}"

  # --- Ensure default map settings exist if needed ---
  # If map settings aren't mounted via configmap/volume, copy defaults so --create works.
  if [ ! -f "${MAP_GEN_SETTINGS_PATH}" ]; then
    echo "Copying default map-gen-settings.json to config volume..."
    # Use the default settings provided with the Factorio installation
    cp data/map-gen-settings.example.json "${MAP_GEN_SETTINGS_PATH}" || { echo "Failed to copy default map-gen-settings.json"; exit 1; }
  fi
  if [ ! -f "${MAP_SETTINGS_PATH}" ]; then
    echo "Copying default map-settings.json to config volume..."
    # Use the default settings provided with the Factorio installation
    cp data/map-settings.example.json "${MAP_SETTINGS_PATH}" || { echo "Failed to copy default map-settings.json"; exit 1; }
  fi
  # --- End map settings check ---

  FACTORIO_START_COMMAND="--create ${FIRST_SAVE_NAME}"
fi
# --- End save check ---


echo "Starting Factorio server..."
echo "Using command: ${FACTORIO_START_COMMAND}."
# Use the determined start command
./bin/x64/factorio \
  --config "${CONFIG_INI_PATH}" \
  --server-settings "${SERVER_SETTINGS_PATH}" \
  --map-gen-settings "${MAP_GEN_SETTINGS_PATH}" \
  --map-settings "${MAP_SETTINGS_PATH}" \
  ${FACTORIO_START_COMMAND} \
  "$@" # Pass any extra arguments

FACTORIO_START_COMMAND="--start-server-load-latest"
echo "Starting server again with: ${FACTORIO_START_COMMAND}."

./bin/x64/factorio \
  --config "${CONFIG_INI_PATH}" \
  --server-settings "${SERVER_SETTINGS_PATH}" \
  --map-gen-settings "${MAP_GEN_SETTINGS_PATH}" \
  --map-settings "${MAP_SETTINGS_PATH}" \
  ${FACTORIO_START_COMMAND} \
  "$@" # Pass any extra arguments
  
# Script won't reach here if exec is successful
echo "Factorio server exited."
exit 1
