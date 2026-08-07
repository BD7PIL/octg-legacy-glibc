#!/bin/bash
# =============================================================================
# Integration tests for the octg-legacy-glibc tarball
# Runs inside a CentOS 7 (glibc 2.17) container.
# =============================================================================
set -e

cd /opt/octg
PASS=0
FAIL=0

pass() { echo "  PASS"; PASS=$((PASS + 1)); }
fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); }

# ── Test 1: opencode wrapper chain ───────────────────────────────────────────
echo "=== Test 1: opencode wrapper chain ==="
# Capture output to detect Permission denied or similar errors.
# Do NOT grep for "opencode" in the output — the error message itself contains
# the word "opencode", which would cause a false positive.
VERSION_OUTPUT=$(bin/opencode --version 2>&1 || true)
if echo "$VERSION_OUTPUT" | grep -qiE 'permission denied|cannot execute|no such file'; then
    fail "opencode wrapper error: $(echo "$VERSION_OUTPUT" | head -3)"
elif bin/opencode --version >/dev/null 2>&1; then
    pass
elif bin/opencode --help >/dev/null 2>&1; then
    pass
else
    fail "opencode wrapper did not execute"
fi

# ── Test 2: clear_ldpath.so is statically linked ─────────────────────────────
echo "=== Test 2: clear_ldpath.so is statically linked ==="
if ldd lib/clear_ldpath.so 2>&1 | grep -qi "static\|not a dynamic"; then
    pass
else
    fail "clear_ldpath.so is not statically linked"
fi

# ── Test 3: musl loader path file created ────────────────────────────────────
echo "=== Test 3: musl loader path file created ==="
# Run opencode once to trigger .path file creation, then check
bin/opencode --version >/dev/null 2>&1 || true
if [ -f /tmp/etc/ld-musl-x86_64.path ]; then
    # Verify the path file contains the correct lib directory
    CONTENT=$(cat /tmp/etc/ld-musl-x86_64.path)
    if [ "$CONTENT" = "/opt/octg/lib" ]; then
        pass
    else
        fail "path file content unexpected: $CONTENT"
    fi
else
    fail "/tmp/etc/ld-musl-x86_64.path not found"
fi

# ── Test 4: Node.js runtime ──────────────────────────────────────────────────
echo "=== Test 4: Node.js runtime ==="
echo "  ldd output:"
ldd node/bin/node 2>&1 | head -10 | sed 's/^/    /'
NODE_VER=$(node/bin/node --version 2>&1 || true)
if echo "$NODE_VER" | grep -q "^v22"; then
    echo "  Node.js $NODE_VER"
    pass
else
    fail "Node.js not working: $NODE_VER"
fi

# ── Test 4b: Node satisfies bot engines requirement ─────────────────────────
echo "=== Test 4b: Node satisfies bot engines ==="
BOT_ENGINES=$(node/bin/node -e "console.log(require('./bot/package.json').engines?.node || '')" 2>/dev/null || true)
if [ -z "$BOT_ENGINES" ]; then
    fail "bot engines.node not readable: $BOT_ENGINES"
else
    MIN_NODE=$(echo "$BOT_ENGINES" | sed 's/[^0-9.]*//g' | cut -d. -f1)
    CUR_MAJOR=$(node/bin/node -e "console.log(process.versions.node.split('.')[0])" 2>/dev/null)
    echo "  bot engines.node=$BOT_ENGINES  current major=$CUR_MAJOR"
    if [ -n "$CUR_MAJOR" ] && [ "$CUR_MAJOR" -ge "$MIN_NODE" ]; then
        pass
    else
        fail "Node $CUR_MAJOR does not satisfy bot engines >=$MIN_NODE"
    fi
fi

# ── Test 4c: opencode-telegram wrapper smoke test (bundled Node) ────────────
echo "=== Test 4c: opencode-telegram wrapper smoke ==="
if bin/opencode-telegram --help 2>&1 | grep -qiE 'opencode-telegram|Usage:'; then
    pass
else
    fail "opencode-telegram wrapper did not execute"
fi

# ── Test 5: Bot files present ────────────────────────────────────────────────
echo "=== Test 5: Bot files present ==="
if [ -f bot/dist/cli.js ] && [ -f bot/package.json ]; then
    pass
else
    fail "bot/dist/cli.js or bot/package.json missing"
fi

# ── Test 6: better-sqlite3 native module ─────────────────────────────────────
echo "=== Test 6: better-sqlite3 native module ==="
if node/bin/node -e "require('/opt/octg/bot/node_modules/better-sqlite3')" 2>/dev/null; then
    pass
else
    fail "better-sqlite3 could not be loaded"
fi

# ── Test 7: octg script exists and is executable ─────────────────────────────
echo "=== Test 7: octg script exists ==="
if [ -x octg ]; then
    pass
else
    fail "octg script not found or not executable"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
echo "========================================="
echo "Results: $PASS passed, $FAIL failed"
echo "========================================="

[ "$FAIL" -eq 0 ] && exit 0 || exit 1
