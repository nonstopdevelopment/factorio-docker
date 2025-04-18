#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status.

# Use environment variables defined in Dockerfile or overridden at runtime
cd "${FACTORIO_DIR}"

echo "Running as user: $(whoami) (ID: $(id -u))"
echo "Working directory: $(pwd)"
echo "Attempting to write to .: $(touch ./test_write && rm ./test_write && echo OK || echo FAILED)"
echo "Attempting to write to saves: $(touch ${FACTORIO_SAVES_DIR}/test_write && rm ${FACTORIO_SAVES_DIR}/test_write && echo OK || echo FAILED)"
echo "Attempting to write to config: $(touch ${FACTORIO_CONFIG_DIR}/test_write && rm ${FACTORIO_CONFIG_DIR}/test_write && echo OK || echo FAILED)"


# Check if server-settings.json already exists (e.g., from a mounted volume)
if [ ! -f "server-settings.json" ]; then
  echo "Generating server-settings.json from template..."
  jq '.username = env.FACTORIO_USERNAME | .password = env.FACTORIO_PASSWORD | .name = env.FACTORIO_SERVER_NAME | .description = env.FACTORIO_SERVER_DESCRIPTION' \
     server-settings-template.json > server-settings.json
else
  echo "Using existing server-settings.json."
  # Optionally: Update specific fields if needed, e.g.,
  # jq --arg user "$FACTORIO_USERNAME" --arg pass "$FACTORIO_PASSWORD" '.username = $user | .password = $pass' server-settings.json > tmp.$$.json && mv tmp.$$.json server-settings.json
fi

echo "Starting Factorio server..."

# Use exec to replace the shell process with the Factorio process
# This makes Factorio PID 1 in the container (after the entrypoint script finishes)
# Pass any arguments passed to the script (e.g., from CMD or Kubernetes args) to the factorio binary
exec ./bin/x64/factorio --start-server-load-latest --server-settings server-settings.json "$@"

# The script will not reach here if exec is successful
echo "Factorio server exited."
exit 1