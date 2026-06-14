# =============================================================================
# Build opencode-telegram-bot on CentOS 7 (glibc 2.17)
# =============================================================================
# Outputs to /output/:
#   dist/cli.js           - bot entry point
#   package.json
#   node_modules/         - compiled for glibc 2.17 (includes better-sqlite3)
# =============================================================================

FROM centos:7 AS builder

# ── CentOS 7 is EOL — switch to vault mirrors ────────────────────────────────
RUN sed -i 's|^mirrorlist=|#mirrorlist=|g' /etc/yum.repos.d/CentOS-*.repo \
    && sed -i 's|^#baseurl=http://mirror.centos.org|baseurl=http://vault.centos.org|g' /etc/yum.repos.d/CentOS-*.repo

# ── Install build tools ──────────────────────────────────────────────────────
# Write SCL repo config directly (avoid centos-release-scl which triggers
# yum metadata refresh on dead mirrorlist before sed can fix it)
RUN printf '[centos-sclo-rh]\nname=CentOS-7 - SCLo rh\nbaseurl=http://vault.centos.org/7.9.2009/sclo/$basearch/rh/\ngpgcheck=0\nenabled=1\n\n[centos-sclo-sclo]\nname=CentOS-7 - SCLo sclo\nbaseurl=http://vault.centos.org/7.9.2009/sclo/$basearch/sclo/\ngpgcheck=0\nenabled=1\n' > /etc/yum.repos.d/CentOS-SCLo.repo \
    && yum install -y \
        devtoolset-8-gcc \
        devtoolset-8-gcc-c++ \
        devtoolset-8-make \
        git \
        curl \
        xz \
        python3 \
    && yum clean all

# ── Install Node.js 20 (glibc-217 unofficial build) ─────────────────────────
ARG NODE_VERSION=20.18.1
RUN curl -fsSL "https://unofficial-builds.nodejs.org/download/release/v${NODE_VERSION}/node-v${NODE_VERSION}-linux-x64-glibc-217.tar.xz" \
        | tar xJ -C /usr/local --strip-components=1 \
    && node --version && npm --version

# ── Clone and build opencode-telegram-bot ─────────────────────────────────────
ARG BOT_VERSION
RUN test -n "$BOT_VERSION" || { echo "ERROR: BOT_VERSION build-arg required"; exit 1; }

WORKDIR /tmp/build
RUN git clone --depth 1 --branch "v${BOT_VERSION}" \
        https://github.com/grinev/opencode-telegram-bot.git .

# Enable devtoolset-8 for glibc 2.17 compatible native modules
SHELL ["/bin/bash", "-c"]
RUN source /opt/rh/devtoolset-8/enable \
    && npm ci \
    && npm run build

# ── Collect output ────────────────────────────────────────────────────────────
# Node.js binary goes to /output/node/bin/node (glibc-2.17 compatible)
# Bot files go to /output/dist/, /output/package.json, /output/node_modules/
RUN mkdir -p /output/node/bin \
    && cp /usr/local/bin/node /output/node/bin/node \
    && cp -r dist /output/ \
    && cp package.json /output/ \
    && cp -r node_modules /output/

# ── Export only /output/ (excludes CentOS rootfs from type=local output) ──────
FROM scratch
COPY --from=builder /output/ /
