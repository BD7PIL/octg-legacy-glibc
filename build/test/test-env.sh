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
if bin/opencode --version 2>/dev/null; then
    pass
else
    # --version may exit non-zero on some builds; check that it ran at all
    if bin/opencode --help 2>&1 | head -5 | grep -qi "opencode\|usage"; then
        pass
    else
        fail "opencode wrapper did not execute"
    fi
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
if echo "$NODE_VER" | grep -q "^v20"; then
    echo "  Node.js $NODE_VER"
    pass
else
    fail "Node.js not working: $NODE_VER"
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
