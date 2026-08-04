# Aether OpenWrt Client Guide

This client integrates the Aether core with OpenWrt. It installs the Aether
binary, a procd service, the `aether-ctl` command, and a LuCI page under
**Services -> Aether**.

## What it does

Aether creates a local SOCKS5 proxy and sends traffic through a censorship-
circumvention tunnel. The OpenWrt integration:

- starts and supervises the core with procd;
- stores identities under `/etc/aether`;
- exposes start, stop, restart, status, logs, and connection tests;
- provides a LuCI configuration page;
- checks the data plane and restarts a stuck core after repeated failures.

The default proxy is `0.0.0.0:1819`. Change it to `127.0.0.1:1819` when the
proxy should be available only on the router itself.

## Protocols

- **MASQUE**: modern HTTP/3/QUIC by default. Enable **HTTP/2** when UDP or
  QUIC is blocked. `firewall` is the recommended MASQUE profile.
- **WireGuard**: usually fast on networks where WireGuard traffic is allowed.
  Use `balanced`, `aggressive`, `light`, or `off`.
- **WARP-in-WARP (gool)**: two WireGuard layers. It can work on stricter
  networks, but has more overhead. Start with the `balanced` profile.

The client scans candidate endpoints and validates real data flow before
exposing SOCKS5. **Quick Reconnect** first verifies the last successful
endpoint and avoids a full scan when possible.

## Settings

### Basic and network settings

- **Enable on Boot** controls automatic startup after a router reboot. It does
  not prevent the Start and Stop buttons or CLI commands from controlling the
  current runtime.
- **Scan Mode**: `turbo` is fastest; `balanced` is the normal choice;
  `thorough`, `stealth`, and `ironclad` trade time for discovery or validation.
- **IP Version**: use IPv4 unless the router has working IPv6.
- **Force Peer**: optionally skip scanning and use a known `ip:port`.
- **HTTP/2 Mode** and **H2 Peer** apply only to MASQUE.
- **TLS Fragmentation** applies to MASQUE HTTP/2 when its handshake is blocked.

### Reliability settings

- **Keepalive** applies to WireGuard and gool.
- **Reconnect Delay** controls the core retry delay.
- **Validation Timeout** controls the data-plane validation wait.
- **Quick Reconnect** rechecks the cached endpoint before scanning.
- **Data-plane Watchdog** periodically tests traffic through SOCKS5. After
  repeated failures it terminates the stuck core and lets procd start a clean
  instance. Install `curl` to enable it.

## Zero Trust

The LuCI **Zero Trust** section supports headless Cloudflare organization
enrollment with:

- Team name;
- Access client ID;
- Access client secret;
- optional organization Gateway mode.

The secret is stored in `/etc/config/aether`, protected as a root-only file,
and redacted from CLI output and service command listings. Gateway mode is
off by default because organization filtering and logging are opt-in.

Interactive email-code enrollment should be performed with the Aether core
directly from an interactive terminal, not from the boot service.

## CLI

```sh
aether-ctl start
aether-ctl stop
aether-ctl restart
aether-ctl status
aether-ctl show
aether-ctl log 100
aether-ctl test google.com
aether-ctl set protocol wg
```

`Enable on Boot` is separate from runtime control:

```sh
aether-ctl set enabled yes   # enable startup after reboot
aether-ctl set enabled no    # disable startup after reboot
aether-ctl start             # start now, regardless of boot setting
aether-ctl stop              # stop now, regardless of boot setting
```

## Install and update

Run the installer as root on the router. It downloads the matching musl
binary, verifies its SHA-256 checksum, stages all support files, preserves
existing configuration by default, refreshes LuCI caches, and restarts the
required web services.

```sh
wget -qO /tmp/aether-install.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/install.sh
chmod +x /tmp/aether-install.sh
/tmp/aether-install.sh --start
```

If the new LuCI page does not appear after an update, sign out and back in,
use `Ctrl+F5`, or open LuCI in an incognito/private window or a different
browser. Browser JavaScript caches can keep the previous page.

## Uninstall

Normal removal keeps configuration and identities:

```sh
wget -qO /tmp/aether-uninstall.sh https://raw.githubusercontent.com/moein8668-git/aether-openwrt-client/main/uninstall.sh
chmod +x /tmp/aether-uninstall.sh
/tmp/aether-uninstall.sh
```

Use `--purge` only when you also want to delete `/etc/config/aether` and
`/etc/aether`, including registered identities.

## Troubleshooting

- Check service state: `aether-ctl status`.
- Read recent logs: `aether-ctl log 100`.
- Test through the tunnel: `aether-ctl test google.com`.
- If the service is running but traffic fails, wait for the watchdog or use
  `aether-ctl restart`.
- If LuCI is stale, use a private window or a fresh browser before reinstalling.
