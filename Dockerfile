# Use a specific Debian version for reproducibility
FROM debian:bookworm-slim

# Combine RUN commands to reduce layers and clean up apt cache
RUN apt-get update && \
    apt-get install -y --no-install-recommends curl xz-utils jq ca-certificates && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

# Create a non-root user and group for Factorio
# Using a fixed UID/GID (e.g., 1001) can be helpful, but OKD might override it anyway.
# Creating the user is the essential part.
ARG FACTORIO_USER=factorio
ARG FACTORIO_GROUP=factorio
ARG FACTORIO_UID=1001
ARG FACTORIO_GID=1001
RUN groupadd --gid ${FACTORIO_GID} ${FACTORIO_GROUP} && \
    useradd --uid ${FACTORIO_UID} --gid ${FACTORIO_GROUP} --shell /bin/bash --create-home --home-dir /factorio ${FACTORIO_USER}

# Set up the Factorio directory structure owned by the factorio user BEFORE downloading
WORKDIR /factorio
RUN chown ${FACTORIO_USER}:${FACTORIO_GROUP} /factorio

# Switch to the non-root user TEMPORARILY for download/extract if needed,
# or keep as root and chown afterwards (simpler here).

# Download and extract Factorio as root (easier for initial setup)
ADD https://factorio.com/get-download/stable/headless/linux64 /tmp/factorio.tar.xz
RUN tar -xf /tmp/factorio.tar.xz -C /factorio && \
    rm /tmp/factorio.tar.xz

# Verify extraction (optional)
# RUN ls -l /factorio/factorio

# Set Environment Variables (can also be set at runtime in Kubernetes)
ENV FACTORIO_USERNAME="test"
ENV FACTORIO_PASSWORD="password"
ENV FACTORIO_SERVER_NAME="FUN SERVER"
ENV FACTORIO_SERVER_DESCRIPTION="A fun server."
# Define paths for clarity
ENV FACTORIO_DIR=/factorio/factorio
ENV FACTORIO_SAVES_DIR=${FACTORIO_DIR}/saves
ENV FACTORIO_CONFIG_DIR=${FACTORIO_DIR}/config
ENV FACTORIO_MODS_DIR=${FACTORIO_DIR}/mods
ENV FACTORIO_LOG_DIR=${FACTORIO_DIR}/logs

# Change ownership of the extracted files to the factorio user
# This is the CRUCIAL step for runtime permissions
RUN chown -R ${FACTORIO_USER}:${FACTORIO_GROUP} /factorio

# Switch to the non-root user for subsequent operations
USER ${FACTORIO_USER}

# Set working directory for the factorio user
WORKDIR ${FACTORIO_DIR}

# Clean up default mods (as non-root user)
RUN rm -rf data/elevated-rails data/quality data/space-age

# Create the initial save file AS THE NON-ROOT USER
# Also create necessary directories Factorio might expect
RUN mkdir -p ${FACTORIO_SAVES_DIR} ${FACTORIO_CONFIG_DIR} ${FACTORIO_MODS_DIR} ${FACTORIO_LOG_DIR} && \
    ./bin/x64/factorio --create ${FACTORIO_SAVES_DIR}/my-save.zip

# Copy configuration templates (owned by factorio user due to USER instruction)
COPY --chown=${FACTORIO_USER}:${FACTORIO_GROUP} server-settings-template.json ${FACTORIO_DIR}/server-settings-template.json

# Expose the Factorio port
EXPOSE 34197/udp

# Copy and set executable permission for the entrypoint script
COPY --chown=${FACTORIO_USER}:${FACTORIO_GROUP} entry_point.sh ${FACTORIO_DIR}/entry_point.sh
RUN chmod +x ${FACTORIO_DIR}/entry_point.sh

# Set the entrypoint
ENTRYPOINT ["/factorio/factorio/entry_point.sh"]

# Optional: Set a default command (can be overridden)
# CMD ["--start-server-load-latest"]