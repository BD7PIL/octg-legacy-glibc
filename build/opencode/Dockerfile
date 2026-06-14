# =============================================================================
# Multi-stage build: package opencode musl binary with bundled libs
# =============================================================================
# Outputs to /output/:
#   bin/opencode          - outer wrapper (musl .path + serve→web)
#   bin/opencode.bin      - inner wrapper (LD_PRELOAD)
#   lib/opencode          - musl binary (patchelf'd interpreter)
#   lib/ld-musl-x86_64.so.1
#   lib/libgcc_s.so.1
#   lib/libstdc++.so.6
#   lib/clear_ldpath.so
# =============================================================================

FROM alpine:3.19 AS builder

RUN apk add --no-cache \
    patchelf \
    wget \
    gcc \
    musl-dev \
    libstdc++ \
    libgcc \
    binutils

ARG OPENCODE_VERSION
RUN test -n "$OPENCODE_VERSION" || { echo "ERROR: OPENCODE_VERSION build-arg required"; exit 1; }

# ── Download and extract opencode musl binary ────────────────────────────────
WORKDIR /tmp/build
RUN wget -q "https://github.com/anomalyco/opencode/releases/download/v${OPENCODE_VERSION}/opencode-linux-x64-musl.tar.gz" \
        -O opencode.tar.gz \
    && tar xzf opencode.tar.gz \
    && rm opencode.tar.gz

# ── Patch ELF interpreter to our custom musl loader path ─────────────────────
RUN patchelf --set-interpreter /tmp/.octg-ld/ld-musl-x86_64.so.1 opencode

# ── Compile clear_ldpath.so (statically linked, zero external deps) ──────────
COPY clear_ldpath.c /tmp/build/clear_ldpath.c
RUN gcc -shared -static -o clear_ldpath.so clear_ldpath.c

# ── Collect musl runtime libraries ───────────────────────────────────────────
# ld-musl-x86_64.so.1 from /lib/
# libgcc_s.so.1 and libstdc++.so.6 from /usr/lib/
RUN mkdir -p /output/lib /output/bin \
    && cp /lib/ld-musl-x86_64.so.1        /output/lib/ \
    && cp /usr/lib/libgcc_s.so.1           /output/lib/ \
    && cp /usr/lib/libstdc++.so.6          /output/lib/ \
    && cp /tmp/build/clear_ldpath.so       /output/lib/ \
    && cp /tmp/build/opencode              /output/lib/opencode

# ── Copy wrapper scripts ─────────────────────────────────────────────────────
COPY opencode     /output/bin/opencode
COPY opencode.bin /output/bin/opencode.bin
RUN chmod +x /output/bin/opencode /output/bin/opencode.bin /output/lib/opencode

# ── Export only /output/ (excludes Alpine rootfs from type=local output) ──────
FROM scratch
COPY --from=builder /output/ /
