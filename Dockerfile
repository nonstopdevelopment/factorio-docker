FROM debian:bookworm
RUN apt update && apt install -y curl xz-utils jq
ADD https://factorio.com/get-download/stable/headless/linux64 /opt/factorio.tar.xz
WORKDIR /opt/
RUN tar -xf factorio.tar.xz
RUN ls -l

WORKDIR /opt/factorio

ENV FACTORIO_USERNAME="test"
ENV FACTORIO_PASSWORD="password"
ENV FACTORIO_SERVER_NAME="FUN SERVER"
ENV FACTORIO_SERVER_DESCRIPTION="A fun server."

RUN rm -rf data/elevated-rails
RUN rm -rf data/quality
RUN rm -rf data/space-age

RUN ./bin/x64/factorio --create ./saves/my-save.zip

COPY server-settings-template.json /opt/factorio/server-settings-template.json

COPY entry_point.sh /opt/factorio/entry_point.sh
RUN chmod +x /opt/factorio/entry_point.sh

EXPOSE 34197/udp

RUN useradd -ms /bin/bash factorio
RUN chown -R factorio:factorio /opt/factorio
USER factorio
ENTRYPOINT ["/opt/factorio/entry_point.sh"]