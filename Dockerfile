FROM debian:bookworm

RUN apt update && apt install -y curl xz-utils jq

ADD https://factorio.com/get-download/stable/headless/linux64 /factorio/factorio.tar.xz

WORKDIR /factorio/

RUN tar -xf factorio.tar.xz
RUN ls -l

ENV FACTORIO_USERNAME="test"
ENV FACTORIO_PASSWORD="password"
ENV FACTORIO_SERVER_NAME="FUN SERVER"
ENV FACTORIO_SERVER_DESCRIPTION="A fun server."

WORKDIR /factorio/factorio

RUN rm -rf data/elevated-rails
RUN rm -rf data/quality
RUN rm -rf data/space-age

RUN ./bin/x64/factorio --create ./saves/my-save.zip

COPY server-settings-template.json /factorio/factorio/server-settings-template.json

EXPOSE 34197/udp

COPY entry_point.sh /factorio/factorio/entry_point.sh
RUN chmod +x /factorio/factorio/entry_point.sh

ENTRYPOINT ["/factorio/factorio/entry_point.sh"]