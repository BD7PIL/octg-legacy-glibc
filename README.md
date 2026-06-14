# octg-legacy-glibc

Run [opencode](https://github.com/anomalyco/opencode) + [opencode-telegram-bot](https://github.com/grinev/opencode-telegram-bot) on **RHEL 7 / CentOS 7 / Scientific Linux 7** (glibc 2.17) systems.

This repo produces CI-built tarballs that bundle everything needed — no system upgrades or external dependencies required beyond `git` and `curl`.

## How It Works

The opencode binary is built against **musl libc** (not glibc).  The tarball ships with:

- A bundled **musl dynamic linker** (`ld-musl-x86_64.so.1`) and runtime libraries (`libstdc++`, `libgcc`)
- A **patched ELF interpreter** that loads the musl linker from `/tmp/.octg-ld/`
- A **`.path` file mechanism** so the musl linker can find bundled libraries without `LD_LIBRARY_PATH`
- A **clear\_ldpath.so** shim that unsets `LD_PRELOAD` after loading (prevents leaking to child processes)
- A **bundled Node.js 20** (glibc-217 unofficial build) for the Telegram bot
- The **opencode-telegram-bot** compiled on CentOS 7 (native `better-sqlite3` against glibc 2.17)

The result: opencode runs via musl isolation while the bot uses the system's glibc 2.17.

## Prerequisites

| Requirement | Notes |
|---|---|
| glibc 2.17+ | RHEL 7, CentOS 7, SL 7, or compatible |
| 2 GB RAM minimum | opencode + Node.js bot |
| `curl` | For setup script (pre-installed on most systems) |
| `git` | Required by opencode (`yum install git` if missing) |

## Install

```bash
# Download the latest release tarball from GitHub Releases
# (check the Releases page for the exact URL)
curl -LO https://github.com/pedropombeiro/octg-legacy-glibc/releases/latest/download/octg-legacy-glibc.tar.gz

# Extract
tar xzf octg-legacy-glibc.tar.gz
cd octg

# Run interactive setup
./setup.sh
```

The setup script will:

1. Prompt for your Telegram bot token(s), user ID, and server password
2. Write configuration to `~/.config/octg/config.env` (chmod 600)
3. Add the bundled binaries to your `PATH`
4. Configure SSH-friendly shell setup (`.bash_profile` → `.bashrc`)
5. Optionally set up `@reboot` crontab for auto-restore

## Configuration

Configuration lives in `~/.config/octg/config.env`:

| Variable | Required | Description |
|---|---|---|
| `OCTG_BOT_TOKEN_1` | Yes | Telegram bot token (add `_2`, `_3`, ... for multiple bots) |
| `OCTG_ALLOWED_USER_ID` | Yes | Your Telegram user ID |
| `OPENCODE_SERVER_PASSWORD` | Recommended | Server password (protects the API) |
| `OCTG_MODEL_PROVIDER` | No | Override default model provider |
| `OCTG_MODEL_ID` | No | Override default model ID |
| `OCTG_BOT_LOCALE` | No | Bot language (e.g. `en`, `zh`) |
| `OCTG_PORTS` | No | Available ports (default: `4096 4097`) |
| `OCTG_DEVTOOLSET` | No | devtoolset version for native modules (auto-detected) |

## Commands

```bash
octg start <dir> [web|server]   # Start a new instance (default: web, binds 0.0.0.0)
octg stop <port|all>            # Stop instance(s) — "all" preserves the current bot
octg restart <port>             # Restart an instance
octg list                       # List all instances
octg status [port]              # Show instance details
octg restore                    # Restore previously running instances
```

## Telegram Usage

In your Telegram chat with the bot, use the `!` prefix to run shell commands:

```
!octg start ~/my-project       Start a web-mode instance
!octg stop all                  Stop all instances
!octg list                      List running instances
```

## Auto-Restore

If you enabled auto-restore during setup, a `@reboot` crontab entry runs `octg restore` on boot.  This restarts any instances that were running when the system shut down.

## Upgrading

1. Download the new release tarball
2. Extract over the existing directory (or to a new location)
3. Re-run `./setup.sh` — it will detect the upgrade, preserve or overwrite config as needed, and offer to stop running instances

## Provider Setup

For model provider and authentication configuration, see the [opencode documentation](https://opencode.ai/docs).

## Troubleshooting

### opencode won't start

- Verify the musl loader symlink exists: `ls -la /tmp/.octg-ld/ld-musl-x86_64.so.1`
- Verify the `.path` file: `cat /tmp/etc/ld-musl-x86_64.path` (should contain the `lib/` directory path)
- Check the wrapper: `bin/opencode --version`
- Ensure `/tmp` is not mounted `noexec`

### bot crashes

- Verify the bundled Node.js works: `node/bin/node --version` (should print v20.x)
- Check that `better-sqlite3` loads: `node/bin/node -e "require('./bot/node_modules/better-sqlite3')"`
- If native module errors occur, ensure `devtoolset` is available (check `OCTG_DEVTOOLSET` in config)
- Check logs: `cat ~/.config/octg/log-<port>.out`

### git not found

Install git:

```bash
yum install git
```

### Port already in use

```bash
octg list                       # See which ports are occupied
octg stop <port>                # Free a specific port
```

## Acknowledgments

- [opencode](https://github.com/anomalyco/opencode) — the AI coding agent
- [opencode-telegram-bot](https://github.com/grinev/opencode-telegram-bot) — Telegram interface for opencode
- [pedropombeiro/opencode-legacy-glibc](https://github.com/pedropombeiro/opencode-legacy-glibc) — musl isolation technique inspiration

## License

MIT — see [LICENSE](LICENSE).
