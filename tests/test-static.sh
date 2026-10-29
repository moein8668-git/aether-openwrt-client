#!/bin/sh
# Lightweight source contract checks; runnable with BusyBox ash.

set -eu
ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

assert_contains() {
	file="$1"
	text="$2"
	grep -F -e "$text" "$ROOT/$file" >/dev/null ||
		{ echo "missing '$text' in $file" >&2; exit 1; }
}

assert_contains install.sh 'CLIENT_VERSION="v0.10.0"'
assert_contains install.sh 'DEFAULT_VERSION="v2.4.0"'
assert_contains install.sh '--version'
assert_contains install.sh '--non-interactive'
assert_contains install.sh 'v1.5.0 or newer is required'
assert_contains update.sh 'Aether OpenWrt Client updater'
assert_contains files/usr/bin/aether-ctl 'do_update()'
assert_contains files/usr/bin/aether-run 'umask 077'
assert_contains files/usr/bin/aether-ctl 'do_change_version()'
assert_contains files/usr/bin/aether-ctl 'change-version'
assert_contains files/usr/bin/aether-ctl 'core_supports_v16()'
assert_contains files/usr/bin/aether-ctl 'core_supports_v17()'
assert_contains files/usr/bin/aether-ctl 'redact_url()'
assert_contains files/usr/bin/aether-ctl 'do_check_ip()'
assert_contains files/usr/bin/aether-ctl 'do_passwall_status()'
assert_contains files/usr/bin/aether-ctl 'do_passwall_localhost()'
assert_contains files/usr/bin/aether-ctl 'do_passwall_add_node()'
assert_contains files/usr/bin/aether-ctl 'passwall localhost on|off'
assert_contains files/www/luci-static/resources/view/aether.js 'Passwall2 Integration'
assert_contains files/etc/config/aether "option perf_profile 'low'"
assert_contains files/etc/config/aether "option wiw_outer ''"
assert_contains files/etc/config/aether "option command_mode 'generated'"
assert_contains files/etc/config/aether "option wiw_inner ''"
assert_contains files/etc/config/aether "option mim_outer ''"
assert_contains files/etc/config/aether "option quic_v2 '1'"
assert_contains files/etc/config/aether "option tor_mode 'off'"
assert_contains files/etc/config/aether "option tor_relays 'auto'"
assert_contains files/etc/config/aether "option tor_relay_ports 'web'"
assert_contains files/etc/config/aether "option tor_bridge_file ''"
assert_contains files/etc/config/aether "option tor_http ''"
assert_contains files/etc/config/aether "option exit_loc '!IR'"
assert_contains files/etc/config/aether "option exit_loc_secs '60'"
assert_contains files/etc/config/aether "option psiphon_mode 'off'"
assert_contains files/etc/config/aether "option psiphon_bind '127.0.0.1:1821'"
assert_contains files/etc/config/aether "option psiphon_front 'auto'"
assert_contains files/etc/config/aether "option stats '0'"
assert_contains files/www/luci-static/resources/view/aether.js 'Disable Localhost Proxy'
assert_contains files/www/luci-static/resources/view/aether.js 'Create Aether Node'
assert_contains files/usr/bin/aether-ctl 'check-ip'
assert_contains files/etc/config/aether "option socks_listen '0.0.0.0:1819'"
assert_contains files/etc/config/aether "option startup_secs '30'"
assert_contains files/etc/config/aether "option upstream_proxy ''"
assert_contains files/etc/init.d/aether 'core_version()'
assert_contains files/etc/init.d/aether 'core_supports_v16()'
assert_contains files/etc/init.d/aether 'core_supports_v18()'
assert_contains files/etc/init.d/aether 'core_supports_v19()'
assert_contains files/etc/init.d/aether 'core_supports_v20()'
assert_contains files/etc/init.d/aether 'core_supports_v21()'
assert_contains files/etc/init.d/aether '--exit-loc'
assert_contains files/etc/init.d/aether '--psiphon-reverse'
assert_contains files/etc/init.d/aether '--psiphon-only'
assert_contains files/etc/init.d/aether '--psiphon-bind'
assert_contains files/etc/init.d/aether '--tor-relays'
assert_contains files/etc/init.d/aether '--tor-relay-ports'
assert_contains files/etc/init.d/aether '--tor-bridge-file'
assert_contains files/etc/init.d/aether '--tor-http'
assert_contains files/etc/init.d/aether '--stats'
assert_contains files/etc/init.d/aether '--mim'
assert_contains files/etc/init.d/aether '--no-quic-v2'
assert_contains files/etc/init.d/aether '--ech'
assert_contains files/etc/init.d/aether '--tor-reverse'
assert_contains files/etc/init.d/aether 'fix_tor_state_owners'
assert_contains files/etc/init.d/aether 'identity_sibling()'
assert_contains files/etc/init.d/aether 'select_perf_profile()'
assert_contains files/etc/init.d/aether 'finish_service_instances'
assert_contains files/etc/init.d/aether '"$command_mode" = "manual"'
assert_contains files/etc/init.d/aether 'manual_args'
assert_contains files/etc/init.d/aether 'chmod 755 "$d"'
assert_contains files/etc/init.d/aether 'ls -lad "$d"'
assert_contains files/etc/init.d/aether '--perf'
assert_contains files/etc/init.d/aether '--wiw-outer'
assert_contains files/etc/init.d/aether '--wiw-inner'
assert_contains files/etc/init.d/aether 'core_supports_v17()'
assert_contains files/etc/init.d/aether 'Ignoring HTTP CONNECT proxy'
assert_contains files/etc/init.d/aether 'Ignoring upstream proxy'
assert_contains files/etc/init.d/aether '--http-proxy'
assert_contains files/etc/init.d/aether '--startup-secs'
assert_contains files/etc/init.d/aether '--no-profile-retry'
assert_contains files/etc/init.d/aether '--upstream'
assert_contains files/www/luci-static/resources/view/aether.js "AETHER_CLIENT_VERSION = 'v0.10.0'"
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCoreSupportsV21'
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCoreSupportsV16'
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCoreSupportsV17'
assert_contains files/www/luci-static/resources/view/aether.js "'upstream_proxy'"
assert_contains files/www/luci-static/resources/view/aether.js 'Client Version'
assert_contains files/www/luci-static/resources/view/aether.js 'Core Version'
assert_contains files/www/luci-static/resources/view/aether.js 'doCheckIp'
assert_contains files/www/luci-static/resources/view/aether.js 'Check Public IP'
assert_contains files/www/luci-static/resources/view/aether.js 'test-result-ip'
assert_contains files/www/luci-static/resources/view/aether.js 'Aether v1.5 compatibility mode'
assert_contains files/usr/libexec/rpcd/luci-app-aether 'core_is_v15()'
assert_contains files/usr/libexec/rpcd/luci-app-aether 'core_is_below_v17()'

assert_contains files/usr/bin/aether-ctl 'core_supports_v18()'
assert_contains files/usr/bin/aether-ctl 'core_supports_v19()'
assert_contains files/usr/bin/aether-ctl 'core_supports_v20()'
assert_contains files/usr/bin/aether-ctl 'core_supports_v21()'
assert_contains files/usr/bin/aether-ctl 'mim_outer|mim_inner|mim_peers|quic_v2|tor_mode|tor_bind|tor_dir|tor_bridges'
assert_contains files/usr/bin/aether-ctl 'auto-perf'
assert_contains files/usr/bin/aether-ctl 'perf_profile'
assert_contains files/usr/bin/aether-ctl 'wiw_outer'
assert_contains files/usr/bin/aether-ctl 'check-tor'
assert_contains files/usr/bin/aether-ctl 'check-psiphon'
assert_contains files/usr/bin/aether-ctl 'psiphon-ip'
assert_contains files/usr/bin/aether-ctl 'do_check_psiphon()'
assert_contains files/usr/bin/aether-ctl 'manual_has_psiphon()'
assert_contains files/usr/bin/aether-ctl 'valid_exit_loc()'
assert_contains files/usr/bin/aether-ctl 'Tor: true IP:'
assert_contains files/usr/bin/aether-ctl 'Psiphon requires Aether core v2.1.0 or newer'
assert_contains files/usr/bin/aether-ctl 'psiphon_mode=only cannot be combined with tor_mode=only'
assert_contains files/usr/bin/aether-ctl 'Psiphon reverse mode requires protocol masque'
assert_contains files/usr/bin/aether-ctl 'Invalid exit_loc'
assert_contains files/usr/bin/aether-ctl 'Invalid tor_bind'
assert_contains files/usr/bin/aether-ctl 'Invalid tor_dir'
assert_contains files/usr/bin/aether-ctl 'test)     do_test'
assert_contains files/usr/bin/aether-ctl 'manual_opt()'
assert_contains files/usr/bin/aether-ctl 'manual_has_tor()'
assert_contains files/usr/bin/aether-ctl 'Tor not in custom_command'
assert_contains files/usr/bin/aether-ctl 'Tor requires Aether core v2.0.0 or newer'
assert_contains files/usr/bin/aether-ctl '$key requires Aether core v2.1.0 or newer'
assert_contains files/usr/bin/aether-ctl 'Invalid command_mode'
assert_contains files/www/luci-static/resources/view/aether.js 'Custom Command'
assert_contains files/www/luci-static/resources/view/aether.js 'custom_command'
assert_contains files/www/luci-static/resources/view/aether.js 'form.DummyValue'
assert_contains files/www/luci-static/resources/view/aether.js 'form.TextValue'
assert_contains files/usr/bin/aether-ctl 'Tor reverse mode requires protocol masque'
assert_contains files/usr/bin/aether-ctl 'Show the effective profile'
assert_contains files/usr/bin/aether-ctl '(stored '
assert_contains install.sh 'select_perf_profile()'
assert_contains install.sh 'PT_BINARY'
assert_contains install.sh 'PT_DIR'
assert_contains install.sh '/usr/bin/pt/lyrebird'
assert_contains install.sh 'aether.main.exit_loc=!IR'
assert_contains uninstall.sh 'rm -rf /usr/bin/pt'
assert_contains files/usr/bin/aether-watchdog 'startup_grace=180'
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCoreSupportsV18'
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCoreSupportsV19'
assert_contains files/www/luci-static/resources/view/aether.js 'Performance Profile'
assert_contains files/www/luci-static/resources/view/aether.js 'gool Outer Hop'
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCoreSupportsV20'
assert_contains files/www/luci-static/resources/view/aether.js 'torBind'
assert_contains files/www/luci-static/resources/view/aether.js 'Needs core v2.0'
assert_contains files/www/luci-static/resources/view/aether.js 'Enabled at '
assert_contains files/www/luci-static/resources/view/aether.js 'MASQUE-in-MASQUE'
assert_contains files/www/luci-static/resources/view/aether.js 'Use QUIC v2 Opener'
assert_contains files/www/luci-static/resources/view/aether.js 'Encrypted Client Hello (ECH)'
assert_contains files/www/luci-static/resources/view/aether.js 'Tor (Core v2)'
assert_contains files/www/luci-static/resources/view/aether.js 'Check Tor IP'
assert_contains files/www/luci-static/resources/view/aether.js 'test-result-tor'
assert_contains files/www/luci-static/resources/view/aether.js 'Check Psiphon IP'
assert_contains files/www/luci-static/resources/view/aether.js 'test-result-psiphon'
assert_contains files/www/luci-static/resources/view/aether.js 'doCheckPsiphon'
assert_contains files/www/luci-static/resources/view/aether.js 'Psiphon (Core v2.1)'
assert_contains files/www/luci-static/resources/view/aether.js 'Exit Location Policy'
assert_contains files/www/luci-static/resources/view/aether.js 'Log Traffic Stats'
assert_contains files/www/luci-static/resources/view/aether.js 'Onionoo Relays as Bridges'
assert_contains files/www/luci-static/resources/view/aether.js 'Core v2.1.0 implements firewall and gfw'
# --- Core v2.4 compatibility (client v0.10.0) ---
assert_contains files/etc/init.d/aether 'core_supports_v23()'
assert_contains files/etc/init.d/aether 'core_supports_v24()'
assert_contains files/etc/init.d/aether 'valid_upstream()'
assert_contains files/etc/init.d/aether 'append_tls_options()'
assert_contains files/etc/init.d/aether '--gool-peer'
assert_contains files/etc/init.d/aether '--masque-sni'
assert_contains files/etc/init.d/aether '--api-address'
assert_contains files/etc/init.d/aether '--scan verified'
assert_contains files/usr/bin/aether-run 'AETHER_TLS_VERIFY=0'
assert_contains files/usr/bin/aether-ctl 'core_supports_v23()'
assert_contains files/usr/bin/aether-ctl 'core_supports_v24()'
assert_contains files/usr/bin/aether-ctl 'valid_upstream()'
assert_contains files/usr/bin/aether-ctl 'valid_domain()'
assert_contains files/usr/bin/aether-ctl 'reverse_protocol_ok()'
assert_contains files/usr/bin/aether-ctl 'do_register()'
assert_contains files/usr/bin/aether-ctl 'register) do_register'
assert_contains files/usr/bin/aether-ctl 'requires Aether core v2.3.0 or newer'
assert_contains files/usr/bin/aether-ctl 'requires Aether core v2.4.0 or newer'
assert_contains files/etc/config/aether "option gool_mode 'modern'"
assert_contains files/etc/config/aether "option fragment_size '8-16'"
assert_contains files/usr/libexec/rpcd/luci-app-aether 'socks5 \(server \)'
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCoreSupportsV23'
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCoreSupportsV24'
assert_contains files/www/luci-static/resources/view/aether.js 'gool-modern'
assert_contains files/www/luci-static/resources/view/aether.js 'gool Flavor'
assert_contains files/www/luci-static/resources/view/aether.js 'MASQUE SNI'
assert_contains files/www/luci-static/resources/view/aether.js 'Gateway Certificate Pinning'
assert_contains files/www/luci-static/resources/view/aether.js 'Verified (quiet, v2.4)'
assert_contains install.sh 'gool_mode'
assert_contains install.sh '/usr/share/aether/LICENSES'
assert_contains uninstall.sh '/usr/share/aether'
assert_contains files/usr/bin/aether-ctl 'tunnel_state()'
assert_contains files/usr/bin/aether-ctl 'Invalid tls_alps'
assert_contains files/www/luci-static/resources/view/aether.js 'extractLastFromLogs'
assert_contains install.sh 'Initialized gool_mode'
# --- review fixes: exit_loc must be able to turn the policy off ---------
assert_contains files/usr/bin/aether-ctl 'normalize_exit_loc()'
assert_contains files/usr/bin/aether-ctl 'value="$(normalize_exit_loc "$value")"'
assert_contains files/usr/bin/aether-ctl 'exit-location policy disabled'
assert_contains files/etc/init.d/aether "config_get exit_loc main exit_loc ''"
assert_contains tests/test-helpers.sh 'normalize_exit_loc'
# --- review fixes: reverse Tor/Psiphon is allowed over MIM too ----------
assert_contains files/usr/bin/aether-ctl 'reverse_capable()'
assert_contains files/usr/bin/aether-ctl 'reverse_capable "$proto"'
assert_contains files/usr/bin/aether-ctl 'requires protocol masque, mim'
assert_contains files/etc/init.d/aether '"$protocol" = "mim"'
assert_contains files/etc/init.d/aether 'requires MASQUE, MIM'
# --- review fixes: the watchdog must probe the manual-mode listener ------
assert_contains files/usr/bin/aether-watchdog 'manual_opt()'
assert_contains files/usr/bin/aether-watchdog 'get_config command_mode'
assert_contains files/usr/bin/aether-watchdog 'manual command mode without --bind'
assert_contains tests/test-helpers.sh 'wd_manual_opt'
# --- review fixes: TLS/API values must be validated before they reach core --
assert_contains files/usr/bin/aether-ctl 'valid_tls_list()'
assert_contains files/usr/bin/aether-ctl 'valid_tls_padding()'
assert_contains files/usr/bin/aether-ctl 'tls_kind=ciphers'
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCheckTlsList'
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCheckTlsPadding'
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCheckApiAddress'
assert_contains files/www/luci-static/resources/view/aether.js 'aetherCheckDomain'
# --- review fixes: the status panel must see the readiness marker --------
assert_contains files/www/luci-static/resources/view/aether.js "'-l', '250'"
assert_contains files/www/luci-static/resources/view/aether.js 'opening (waiting for tunnel validation)'
# --- review fixes: display/gating cleanups -------------------------------
assert_contains files/etc/init.d/aether "config_get tls_verify main tls_verify ''"
assert_contains files/etc/init.d/aether '"$masque_side" -eq 1 ] && [ "$supports_v23"'
assert_contains files/usr/bin/aether-ctl '"$gool_effective" = "classic"'
assert_contains files/usr/bin/aether-ctl '"$gool_effective" = "modern"'
assert_contains install.sh '-lastconn.toml'
assert_contains files/usr/bin/aether-ctl 'a number of bytes from 0 to 65535'
# --- review fixes: non-tty prompt and stale-clock diagnosis ---------------
assert_contains files/usr/bin/aether-ctl 'offer_restart()'
assert_contains files/usr/bin/aether-ctl '[ -t 0 ] || return 0'
assert_contains install.sh 'https_hint_text()'
assert_contains install.sh 'FETCH_ERR='
assert_contains tests/test-helpers.sh 'https_hint_text'
# -q would swallow the wget error text the clock hint depends on.
assert_contains install.sh 'RELEASE_JSON=$(wget -4 -T 30 -O- "$API_URL" 2>"$FETCH_ERR")'

# The LuCI validators are JavaScript: exercise them when the host has node.
# OpenWrt has no node, so this is skipped there and the shell suites stay the
# gate on the router.
if command -v node >/dev/null 2>&1; then
	node "$ROOT/tests/test-js-validators.js" || exit 1
fi
echo "static checks passed"
