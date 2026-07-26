[فارسی](README-fa.md) | [English](README.md)

# Aether OpenWrt Client

OpenWrt integration for [Aether](https://github.com/CluvexStudio/Aether) — a censorship circumvention client.

**Aether is developed by [CluvexStudio](https://github.com/CluvexStudio). This repo provides an OpenWrt installer and LuCI web interface.**

## Requirements

- **OpenWrt 24.10 or newer** (musl libc; uses apk on 25.12+, opkg on 24.10 and older)
- Tested on OpenWrt 25.12.5 (x86_64)
- ~10 MB free disk space
- Architectures: x86_64, arm64 (aarch64), armv7

## Install (one line)

```sh
wget -qO /tmp/aether-install.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/install.sh && chmod +x /tmp/aether-install.sh && /tmp/aether-install.sh --start
```

During install you will be asked:

- **Install curl?** Defaults to **No**. curl is only needed for the connection test buttons in LuCI and it will take some storage. Without it the tunnel still works fine. Say `y` if you want the test feature.

## What it does

1. Auto-detects your router architecture (x86_64, arm64, armv7)
2. Downloads the latest official Aether binary from [CluvexStudio/Aether releases](https://github.com/CluvexStudio/Aether/releases)
3. Installs the Aether service (procd), CLI tool, and LuCI web interface
4. Downloads support files (init script, LuCI app, CLI, config) from GitHub

## Features

- **CLI**: `aether-ctl start|stop|restart|status|show|log|test <host>`
- **LuCI**: Services -> Aether
  - Status table (state, version, endpoint, transport, SOCKS5 address)
  - Start / Stop / Restart buttons
  - Connection test buttons with accurate millisecond timing
  - Real-time live logs (auto-updating, pause/resume, auto-scroll)
  - Full configuration (protocol, scan mode, obfuscation, HTTP/2, etc.)
- **Service**: procd integration, auto-start on boot
- **Architecture**: x86_64, arm64, armv7 (musl static builds)

## Install options

```sh
/tmp/aether-install.sh                 # install only
/tmp/aether-install.sh --start         # install and start now
/tmp/aether-install.sh --force-config  # overwrite existing config
/tmp/aether-install.sh --no-curl       # skip curl installation prompt
```

## Uninstall

**(one line)**
```sh
wget -qO /tmp/aether-uninstall.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/uninstall.sh && chmod +x /tmp/aether-uninstall.sh && /tmp/aether-uninstall.sh
```

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
aether-ctl test google.com  # test connection through tunnel (needs curl)
aether-ctl version
```

## LuCI Web Interface

After install, open your router web UI -> **Services -> Aether**

![LuCI Web Interface](screenshots/luci.png)

Features:
- Status table (state, version, endpoint, transport)
- Start / Stop / Restart buttons
- Connection test buttons (google.com, youtube.com, github.com, telegram.org) with accurate ms timing
- Real-time live logs (auto-updating every 2 seconds, no manual refresh needed)
- Pause/Resume log streaming
- Auto-scroll toggle
- Clear logs button
- Full configuration (protocol, scan mode, obfuscation, HTTP/2, etc.)

## Manual update (from your PC)

If you have the repo cloned locally and want to push updated files to your router without going through GitHub:

```sh
# Create a tarball of the files directory
cd aether-openwrt-client
tar czf /tmp/aether-files.tar.gz files/

# Transfer to router (OpenWrt doesn't have scp server, use wget from router)
# On your PC, serve the file temporarily:
python -m http.server 8888 --directory /tmp

# On the router:
wget -O /tmp/aether-files.tar.gz http://<your-pc-ip>:8888/aether-files.tar.gz
tar xzf /tmp/aether-files.tar.gz -C /
/etc/init.d/aether restart
/etc/init.d/rpcd restart
```

Or just re-run the install script (it always fetches the latest files from GitHub):

```sh
wget -qO /tmp/aether-install.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/install.sh && chmod +x /tmp/aether-install.sh && /tmp/aether-install.sh --start
```

## Notes

- Requires OpenWrt 24.10+ with musl libc (apk on 25.12+, opkg on older)
- `curl` is optional (asked during install, defaults to No). Only needed for LuCI connection test buttons.
- This project is not affiliated with CluvexStudio

## License

MIT — this installer and LuCI app only. Aether itself is AGPL-3.0.
