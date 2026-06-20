#!/bin/bash
# =============================================================================
# octg-legacy-glibc — Post-extract interactive setup
# =============================================================================
#
# Run this script once after extracting the tarball.  It:
#   1. Collects Telegram bot tokens, user ID, and server password
#   2. Writes ~/.config/octg/config.env (chmod 600)
#   3. Adds config.env source + PATH to ~/.bashrc
#   4. Ensures ~/.bash_profile sources ~/.bashrc (for SSH sessions)
#   5. Optionally sets up @reboot crontab for auto-restore
#   6. Detects devtoolset if present (for native module rebuilds)
#
# All binaries (opencode, node, bot) are already bundled — no downloads needed.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.octg"
CONFIG_DIR="$HOME/.config/octg"
CONFIG_FILE="$CONFIG_DIR/config.env"

if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
    DOWNLOAD_DIR="$SCRIPT_DIR"
    echo "Installing octg-legacy-glibc to $INSTALL_DIR ..."

    echo "  [INFO]  Removing previous installation at $INSTALL_DIR ..."
    rm -rf "$INSTALL_DIR"
    mkdir -p "$INSTALL_DIR"

    echo "  [INFO]  Copying files from $DOWNLOAD_DIR to $INSTALL_DIR ..."
    cp -a "$SCRIPT_DIR/." "$INSTALL_DIR/"

    echo "  [INFO]  Setting executable permissions ..."
    chmod +x "$INSTALL_DIR"/octg "$INSTALL_DIR"/setup.sh "$INSTALL_DIR"/bin/* "$INSTALL_DIR"/lib/opencode 2>/dev/null || true

    # Verify critical binaries got +x
    missing_x=()
    for f in "$INSTALL_DIR"/bin/opencode "$INSTALL_DIR"/bin/opencode.bin "$INSTALL_DIR"/lib/opencode "$INSTALL_DIR"/node/bin/node; do
        [ -x "$f" ] || missing_x+=("$f")
    done
    if [ ${#missing_x[@]} -gt 0 ]; then
        echo "  [ERROR] The following files are missing execute permission:"
        for f in "${missing_x[@]}"; do
            echo "            $f"
        done
        echo "  [ERROR] Run manually:  chmod +x ${missing_x[*]}"
        exit 1
    fi
    echo "  [INFO]  Executables verified: octg, bin/opencode, bin/opencode.bin, lib/opencode, node/bin/node"

    SCRIPT_DIR="$INSTALL_DIR"
    cd "$SCRIPT_DIR"
    echo "  [INFO]  Done. You may now delete the download at: $DOWNLOAD_DIR"
fi

# ---------------------------------------------------------------------------
# ASCII banner
# ---------------------------------------------------------------------------
print_banner() {
    cat << 'EOF'

   ____  _____ _______  ____
  / __ \/ ___// ____/ |/ __ \
 / / / /\__ \/ / __ |   / /
/ /_/ /___/ / /_/ //   |
\____//____/\____//_/|_|

OpenCode Telegram Group — Setup (legacy-glibc)

EOF
}

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------
info()  { echo "  [INFO]  $*"; }
warn()  { echo "  [WARN]  $*"; }
error() { echo "  [ERROR] $*" >&2; }

# ---------------------------------------------------------------------------
# Interactive configuration
# ---------------------------------------------------------------------------
prompt_config() {
    echo "Configuring octg..."
    echo ""

    # -- Bot tokens (one or more) --
    local tokens=()
    local n=1
    while true; do
        local label="token $n"
        [ "$n" -eq 1 ] && label="token 1 (required)"

        local tok=""
        read -rp "  Enter bot ${label}: " tok

        if [ "$n" -eq 1 ] && [ -z "$tok" ]; then
            error "At least one bot token is required."
            continue
        fi

        [ -z "$tok" ] && break

        tokens+=("$tok")
        n=$((n + 1))
    done

    # -- Telegram user ID --
    local user_id=""
    while true; do
        read -rp "  Enter your Telegram user ID: " user_id
        if [[ "$user_id" =~ ^[0-9]+$ ]]; then
            break
        fi
        error "User ID must be numeric."
    done

    # -- Server password --
    local server_pw=""
    read -rp "  Enter opencode server password (or Enter for none): " server_pw

    # -- Model provider (required by bot) --
    local model_provider=""
    while true; do
        read -rp "  Enter model provider (e.g. zai-coding-plan): " model_provider
        [ -n "$model_provider" ] && break
        error "Model provider is required by opencode-telegram-bot."
    done

    # -- Model ID (required by bot) --
    local model_id=""
    while true; do
        read -rp "  Enter model ID (e.g. glm-5.1): " model_id
        [ -n "$model_id" ] && break
        error "Model ID is required by opencode-telegram-bot."
    done

    # -- Bot locale (optional) --
    local bot_locale=""
    read -rp "  Enter bot locale, e.g. 'en' or 'zh' (or Enter to skip): " bot_locale

    echo ""

    # -- Detect devtoolset --
    local dt_version=""
    for dt_dir in /opt/rh/devtoolset-11 /opt/rh/devtoolset-9 /opt/rh/devtoolset-8; do
        [ -d "$dt_dir" ] || continue
        dt_version="$(basename "$dt_dir" | sed 's/devtoolset-//')"
        break
    done

    # -- Write config.env --
    mkdir -p "$CONFIG_DIR"
    {
        echo "# octg configuration — generated by setup.sh"
        echo "OCTG_OPENCODE_BIN=${SCRIPT_DIR}/bin/opencode"
        for i in "${!tokens[@]}"; do
            echo "OCTG_BOT_TOKEN_$((i + 1))=${tokens[$i]}"
        done
        echo "OCTG_ALLOWED_USER_ID=${user_id}"
        echo "OPENCODE_SERVER_PASSWORD=${server_pw}"
        echo "OCTG_MODEL_PROVIDER=${model_provider}"
        echo "OCTG_MODEL_ID=${model_id}"
        if [ "${#tokens[@]}" -gt 2 ]; then
            local _ports=""
            for i in "${!tokens[@]}"; do
                [ -n "$_ports" ] && _ports+=" "
                _ports+="$((4096 + i))"
            done
            echo "OCTG_PORTS=\"${_ports}\""
        fi
        echo ""
        echo "# PATH for bundled binaries"
        echo "export PATH=\"${SCRIPT_DIR}:${SCRIPT_DIR}/bin:${SCRIPT_DIR}/node/bin:\$PATH\""
        echo ""
        echo "# Optional:"
        [ -n "$bot_locale" ] && echo "OCTG_BOT_LOCALE=${bot_locale}" || echo "#OCTG_BOT_LOCALE="
        if [ -n "$dt_version" ]; then
            echo ""
            echo "OCTG_DEVTOOLSET=${dt_version}"
        fi
    } > "$CONFIG_FILE"

    chmod 600 "$CONFIG_FILE"
    info "Configuration saved to $CONFIG_FILE"
    if [ -n "$dt_version" ]; then
        info "Detected devtoolset-${dt_version}"
    fi
    echo ""
}

# ---------------------------------------------------------------------------
# Shell setup
# ---------------------------------------------------------------------------
setup_shell() {
    echo "Setting up shell..."

    local source_line="source ${CONFIG_FILE}"

    # ~/.bashrc — source config.env
    if ! grep -qxF "$source_line" "$HOME/.bashrc" 2>/dev/null; then
        echo "" >> "$HOME/.bashrc"
        echo "# octg — load configuration" >> "$HOME/.bashrc"
        echo "$source_line" >> "$HOME/.bashrc"
        info "Added config source to ~/.bashrc"
    else
        info "Config source already in ~/.bashrc"
    fi

    # ~/.bash_profile — ensure it sources .bashrc (for SSH sessions)
    local bp_source
    bp_source="$(cat << 'BPEOF'
if [ -f ~/.bashrc ]; then
    source ~/.bashrc
fi
BPEOF
)"

    if [ ! -f "$HOME/.bash_profile" ]; then
        echo "$bp_source" > "$HOME/.bash_profile"
        info "Created ~/.bash_profile (sources .bashrc)"
    elif ! grep -q 'source ~/.bashrc' "$HOME/.bash_profile" 2>/dev/null \
      && ! grep -q '. ~/.bashrc' "$HOME/.bash_profile" 2>/dev/null; then
        echo "" >> "$HOME/.bash_profile"
        echo "$bp_source" >> "$HOME/.bash_profile"
        info "Updated ~/.bash_profile to source .bashrc"
    else
        info "~/.bash_profile already sources .bashrc"
    fi

    echo ""
}

# ---------------------------------------------------------------------------
# Auto-restore on boot
# ---------------------------------------------------------------------------
setup_autorestore() {
    read -rp "  Set up auto-restore on boot? (y/N): " yn
    case "${yn,,}" in
        y|yes)
            local cron_entry="@reboot ${SCRIPT_DIR}/octg restore >> ${CONFIG_DIR}/autorestore.log 2>&1"
            if crontab -l 2>/dev/null | grep -qF "octg restore"; then
                info "Auto-restore crontab entry already exists."
            else
                (crontab -l 2>/dev/null; echo "$cron_entry") | crontab -
                info "Auto-restore added to crontab."
            fi
            ;;
        *)
            info "Skipping auto-restore setup."
            ;;
    esac
    echo ""
}

# ---------------------------------------------------------------------------
# Upgrade detection — stop running instances if requested
# ---------------------------------------------------------------------------
handle_upgrade() {
    if [ ! -f "$CONFIG_FILE" ]; then
        return 0
    fi

    warn "Existing configuration found at $CONFIG_FILE"
    warn "Proceeding with upgrade (config will be overwritten)..."
    echo ""

    # Check for running instances
    local pid_count=0
    for pidfile in "$CONFIG_DIR"/instance-*.pid; do
        [ -f "$pidfile" ] || continue
        local pid
        pid="$(cat "$pidfile" 2>/dev/null)"
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            pid_count=$((pid_count + 1))
        fi
    done

    if [ "$pid_count" -gt 0 ]; then
        warn "Detected ${pid_count} running instance(s)."
        read -rp "  Stop them now? (Y/n): " yn
        case "${yn,,}" in
            n|no)
                info "Leaving instances running."
                ;;
            *)
                if [ -x "${SCRIPT_DIR}/octg" ]; then
                    "${SCRIPT_DIR}/octg" stop all || true
                else
                    warn "octg script not found; stop manually with: octg stop all"
                fi
                ;;
        esac
        echo ""
    fi
}

# ---------------------------------------------------------------------------
# Prerequisite checks
# ---------------------------------------------------------------------------
check_prerequisites() {
    echo "Checking prerequisites..."

    local missing=()

    if ! command -v git &>/dev/null; then
        missing+=(git)
    fi

    if ! command -v curl &>/dev/null; then
        missing+=(curl)
    fi

    if [ ${#missing[@]} -gt 0 ]; then
        error "Missing required tools: ${missing[*]}"
        error "Install them with:  yum install ${missing[*]}"
        exit 1
    fi

    info "git $(git --version | awk '{print $3}')"
    info "curl $(curl --version | head -1 | awk '{print $2}')"

    # Verify bundled Node.js
    if [ -x "${SCRIPT_DIR}/node/bin/node" ]; then
        info "Node.js $("${SCRIPT_DIR}/node/bin/node" --version)"
    else
        warn "Bundled Node.js not found at ${SCRIPT_DIR}/node/bin/node"
    fi

    # Verify bundled opencode
    if [ -x "${SCRIPT_DIR}/bin/opencode" ]; then
        info "opencode wrapper present"
    else
        error "opencode wrapper not found at ${SCRIPT_DIR}/bin/opencode"
        exit 1
    fi

    echo ""
}

# ---------------------------------------------------------------------------
# Completion message
# ---------------------------------------------------------------------------
print_done() {
    cat << DONE

  ────────────────────────────────────────────────

  octg-legacy-glibc setup complete!

  Bundled components:
    opencode:    ${SCRIPT_DIR}/bin/opencode
    Node.js:     ${SCRIPT_DIR}/node/bin/node
    Bot:         ${SCRIPT_DIR}/bin/opencode-telegram
    Manager:     ${SCRIPT_DIR}/octg

  Next steps:
    1. Restart your shell or run:  source ~/.bashrc
    2. Start an instance:          octg start ~/my-project
    3. In Telegram, use:           !octg list

  For provider/auth setup:  https://opencode.ai/docs

  ────────────────────────────────────────────────

DONE
}

# =============================================================================
# Main
# =============================================================================
main() {
    local is_upgrade=false
    [ -f "$CONFIG_FILE" ] && is_upgrade=true

    print_banner
    check_prerequisites

    if $is_upgrade; then
        warn "Existing configuration found at $CONFIG_FILE"
        info "Preserving existing configuration."
        echo ""
        handle_upgrade
        setup_shell
        setup_autorestore
    else
        prompt_config
        setup_shell
        setup_autorestore
    fi

    print_done
}

main "$@"
