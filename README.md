# Aether OpenWrt Client

OpenWrt integration for [Aether](https://github.com/CluvexStudio/Aether) — a censorship circumvention client.

**Aether is developed by [CluvexStudio](https://github.com/CluvexStudio). This repo provides an OpenWrt installer and LuCI web interface.**

## Install (one line)

```sh
wget -qO /tmp/aether-install.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/install.sh && chmod +x /tmp/aether-install.sh && /tmp/aether-install.sh --start
```

## What it does

1. Auto-detects your router architecture (x86_64, arm64, armv7)
2. Downloads the latest official Aether binary from [CluvexStudio/Aether releases](https://github.com/CluvexStudio/Aether/releases)
3. Installs the Aether service (procd), CLI tool, and LuCI web interface

## Features

- **CLI**: `aether-ctl start|stop|restart|status|show|log|test <host>`
- **LuCI**: Services → Aether (status, settings, connection tests, live logs)
- **Service**: procd integration, auto-start on boot
- **Architecture**: x86_64, arm64, armv7 (musl static builds)

## Install options

```sh
./install.sh                 # install only
./install.sh --start         # install and start now
./install.sh --force-config  # overwrite existing config
./install.sh --no-curl       # skip curl installation
```

## Uninstall

```sh
./uninstall.sh           # remove files
./uninstall.sh --purge   # also remove config and identity data
```

## CLI commands

```sh
aether-ctl start
aether-ctl stop
aether-ctl restart
aether-ctl status
aether-ctl show
aether-ctl log              # show recent logs
aether-ctl log 100          # show last 100 lines
aether-ctl test google.com  # test connection through tunnel
aether-ctl version
```

## LuCI Web Interface

After install, open your router web UI → **Services → Aether**

Features:
- Status table (state, version, endpoint, transport)
- Start / Stop / Restart buttons
- Connection test buttons (google.com, youtube.com, github.com, telegram.org)
- Live logs display
- Full configuration (protocol, scan mode, obfuscation, HTTP/2, etc.)

## Notes

- Requires OpenWrt with musl libc
- `curl` is asked during install (optional, needed for connection tests)
- This project is not affiliated with CluvexStudio

## License

MIT — this installer and LuCI app only. Aether itself is AGPL-3.0.
