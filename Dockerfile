# ---
# ListCloud — Docker image for OpenList on free cloud PaaS
# ---
FROM alpine:3.20

LABEL org.opencontainers.image.title="ListCloud"
LABEL org.opencontainers.image.description="Free cloud deployment for OpenList (standard and custom builds)"
LABEL org.opencontainers.image.licenses="AGPL-3.0"

ARG OPENLIST_VERSION=latest
ARG INSTALL_ARIA2=false
ARG INSTALL_FFMPEG=false

RUN apk add --no-cache \
    bash \
    curl \
    jq \
    git \
    ca-certificates \
    tzdata \
    sqlite \
    openssl \
    && if [ "$INSTALL_ARIA2" = "true" ]; then apk add --no-cache aria2; fi \
    && if [ "$INSTALL_FFMPEG" = "true" ]; then apk add --no-cache ffmpeg; fi

# UID 1000 keeps the image compatible with most PaaS platforms
RUN addgroup -g 1000 listcloud && \
    adduser -D -u 1000 -G listcloud -h /opt/openlist listcloud && \
    mkdir -p /opt/openlist/data /opt/openlist/custom /opt/openlist/backup /opt/openlist/aria2

WORKDIR /opt/openlist

# Official OpenList release binary, downloaded at build time
RUN set -eux; \
    ARCH=$(uname -m); \
    case "$ARCH" in \
      x86_64) OL_ARCH="amd64" ;; \
      aarch64|arm64) OL_ARCH="arm64" ;; \
      *) OL_ARCH="amd64" ;; \
    esac; \
    if [ "$OPENLIST_VERSION" = "latest" ]; then \
      URL="https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-linux-musl-${OL_ARCH}.tar.gz"; \
    else \
      URL="https://github.com/OpenListTeam/OpenList/releases/download/${OPENLIST_VERSION}/openlist-linux-musl-${OL_ARCH}.tar.gz"; \
    fi; \
    echo "Downloading ${URL}"; \
    curl -fsSL "$URL" -o /tmp/openlist.tar.gz; \
    tar -xzf /tmp/openlist.tar.gz -C /opt/openlist; \
    chmod +x /opt/openlist/openlist; \
    rm -f /tmp/openlist.tar.gz

COPY --chown=1000:1000 scripts/ /opt/openlist/scripts/
COPY --chown=1000:1000 config/aria2.conf /opt/openlist/aria2/aria2.conf

RUN chmod +x /opt/openlist/scripts/*.sh && \
    chown -R 1000:1000 /opt/openlist

USER 1000

ENV PORT=10000 \
    HTTP_PORT=10000 \
    UMASK=022 \
    TZ=UTC \
    ADMIN_USERNAME=admin \
    ADMIN_PASSWORD="" \
    ENABLE_ARIA2=false \
    ARIA2_SECRET=listcloud_aria2_secret \
    SYNC_MODE=none \
    SYNC_INTERVAL=300 \
    KEEPALIVE_INTERVAL=600 \
    CUSTOM_BINARY_URL="" \
    CUSTOM_DIST_URL=""

EXPOSE 10000

HEALTHCHECK --interval=30s --timeout=10s --start-period=30s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT:-10000}/ping" || exit 1

ENTRYPOINT ["/opt/openlist/scripts/entrypoint.sh"]
