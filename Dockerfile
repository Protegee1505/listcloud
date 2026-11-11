# ---
# title: ListCloud - Free 24/7 OpenList Cloud
# emoji: ☁️
# colorFrom: blue
# colorTo: indigo
# sdk: docker
# app_port: 7860
# pinned: false
# license: agpl-3.0
# ---

FROM alpine:3.20

LABEL org.opencontainers.image.title="ListCloud"
LABEL org.opencontainers.image.description="100% Free, Zero-Credit-Card 24/7 Cloud Hosting for OpenList (Standard & Custom)"
LABEL org.opencontainers.image.licenses="AGPL-3.0"

ARG TARGETARCH
ARG OPENLIST_VERSION=latest
ARG INSTALL_ARIA2=true
ARG INSTALL_FFMPEG=false

# Install runtime dependencies for OpenList, cloud persistence sync, and custom builds
RUN apk add --no-cache \
    bash \
    curl \
    jq \
    git \
    ca-certificates \
    tzdata \
    sqlite \
    rclone \
    openssl \
    su-exec \
    && if [ "$INSTALL_ARIA2" = "true" ]; then apk add --no-cache aria2; fi \
    && if [ "$INSTALL_FFMPEG" = "true" ]; then apk add --no-cache ffmpeg; fi

# Create non-root user with UID 1000 (required by Hugging Face Spaces & compatible with Render/Koyeb)
RUN addgroup -g 1000 listcloud && \
    adduser -D -u 1000 -G listcloud -h /opt/openlist listcloud && \
    mkdir -p /opt/openlist/data /opt/openlist/custom /opt/openlist/backup /opt/openlist/aria2

WORKDIR /opt/openlist

# Download official OpenList binary for target architecture during build as default binary
RUN set -eux; \
    ARCH=$(uname -m); \
    case "$ARCH" in \
      x86_64) OL_ARCH="amd64" ;; \
      aarch64|arm64) OL_ARCH="arm64" ;; \
      armv7l) OL_ARCH="arm-7" ;; \
      *) OL_ARCH="amd64" ;; \
    esac; \
    if [ "$OPENLIST_VERSION" = "latest" ]; then \
      DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList/releases/latest/download/openlist-linux-musl-${OL_ARCH}.tar.gz"; \
    else \
      DOWNLOAD_URL="https://github.com/OpenListTeam/OpenList/releases/download/${OPENLIST_VERSION}/openlist-linux-musl-${OL_ARCH}.tar.gz"; \
    fi; \
    echo "Downloading OpenList from ${DOWNLOAD_URL}..."; \
    curl -fsSL "$DOWNLOAD_URL" -o /tmp/openlist.tar.gz && \
    tar -xzf /tmp/openlist.tar.gz -C /opt/openlist && \
    chmod +x /opt/openlist/openlist && \
    rm -f /tmp/openlist.tar.gz

# Copy cloud runtime scripts and aria2 config
COPY --chown=1000:1000 scripts/ /opt/openlist/scripts/
COPY --chown=1000:1000 config/aria2.conf /opt/openlist/aria2/aria2.conf

RUN chmod +x /opt/openlist/scripts/*.sh && \
    chown -R 1000:1000 /opt/openlist

USER 1000

# Default environment variables tuned for 100% Free Cloud PaaS (HF Spaces port 7860 by default)
ENV PORT=7860 \
    HTTP_PORT=7860 \
    UMASK=022 \
    TZ=UTC \
    ADMIN_USERNAME=admin \
    ADMIN_PASSWORD="" \
    ENABLE_ARIA2=false \
    ARIA2_SECRET=listcloud_aria2_secret \
    SYNC_MODE=none \
    SYNC_INTERVAL=300 \
    KEEPALIVE_URL="" \
    KEEPALIVE_INTERVAL=480 \
    CUSTOM_BINARY_URL="" \
    CUSTOM_DIST_URL=""

EXPOSE 7860 5244

HEALTHCHECK --interval=30s --timeout=10s --start-period=20s --retries=3 \
    CMD curl -fsS "http://127.0.0.1:${PORT:-7860}/ping" || exit 1

ENTRYPOINT ["/opt/openlist/scripts/entrypoint.sh"]
