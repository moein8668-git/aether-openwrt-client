#!/bin/sh
# Behavioural unit tests for the pure shell helpers (BusyBox ash compatible).
# Functions are extracted from the shipped scripts so the tests exercise the
# real code, not a copy.

ROOT="$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
CTL="$ROOT/files/usr/bin/aether-ctl"
INIT="$ROOT/files/etc/init.d/aether"
WD="$ROOT/files/usr/bin/aether-watchdog"
INSTALL="$ROOT/install.sh"
PASS=0
FAIL=0

load_fn() {
	# load_fn <file> <name>
	eval "$(sed -n "/^$2() {/,/^}/p" "$1")"
}

for fn in core_supports_v16 core_supports_v17 core_supports_v20 core_supports_v21 \
	core_supports_v23 core_supports_v24 valid_upstream valid_domain valid_hostport valid_api_address \
	valid_exit_loc normalize_exit_loc reverse_capable valid_tls_list valid_tls_padding; do
	load_fn "$CTL" "$fn"
done
# init.d has its own copy of valid_upstream: test it under another name.
eval "$(sed -n '/^valid_upstream() {/,/^}/p' "$INIT" | sed 's/^valid_upstream()/init_valid_upstream()/')"
# The watchdog carries its own copy of manual_opt: test both copies.
load_fn "$CTL" manual_opt
eval "$(sed -n '/^manual_opt() {/,/^}/p' "$WD" | sed 's/^manual_opt()/wd_manual_opt()/')"
# The installer explains a failed HTTPS fetch (a stale clock is the usual cause).
load_fn "$INSTALL" https_hint_text

t_ok() { # t_ok <desc> <cmd...>
	desc="$1"; shift
	if "$@" >/dev/null 2>&1; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL (expected accept): $desc"; fi
}
t_no() { # t_no <desc> <cmd...>
	desc="$1"; shift
	if "$@" >/dev/null 2>&1; then FAIL=$((FAIL + 1)); echo "FAIL (expected reject): $desc"; else PASS=$((PASS + 1)); fi
}
t_eq() { # t_eq <desc> <expected> <cmd...>
	desc="$1"; exp="$2"; shift 2
	got="$("$@" 2>/dev/null)"
	if [ "$got" = "$exp" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL (expected '$exp', got '$got'): $desc"; fi
}

# --- version gates -----------------------------------------------------
t_no "v2.2.9 !v23" core_supports_v23 2.2.9
t_ok "v2.3.0 v23" core_supports_v23 2.3.0
t_ok "v2.4.0 v23" core_supports_v23 2.4.0
t_ok "v3.0.0 v23" core_supports_v23 3.0.0
t_no "v1.9.0 !v23" core_supports_v23 1.9.0
t_no "v2.3.0 !v24" core_supports_v24 2.3.0
t_ok "v2.4.0 v24" core_supports_v24 2.4.0
t_ok "v2.10.0 v24" core_supports_v24 2.10.0
t_ok "v3.0.0 v24" core_supports_v24 3.0.0
t_no "garbage !v24" core_supports_v24 abc

# --- upstream validation (ctl and init.d must agree) ------------------
for fn in valid_upstream init_valid_upstream; do
	t_ok "$fn host:port" $fn 127.0.0.1:1080
	t_ok "$fn socks5" $fn socks5://127.0.0.1:1080
	t_ok "$fn socks5h creds" $fn socks5h://user:pw@10.0.0.2:1080
	t_ok "$fn http" $fn http://proxy.example.com:8080
	t_ok "$fn https no creds" $fn https://proxy.example.com:443
	t_ok "$fn ipv6" $fn 'socks5://[::1]:1080'
	t_no "$fn https creds" $fn https://u:p@proxy.example.com:443
	t_no "$fn empty" $fn ''
	t_no "$fn no port" $fn socks5://127.0.0.1
	t_no "$fn port 0" $fn 127.0.0.1:0
	t_no "$fn port 70000" $fn 127.0.0.1:70000
	t_no "$fn bad scheme" $fn ftp://127.0.0.1:21
	t_no "$fn port text" $fn 127.0.0.1:abc
	t_no "$fn only port" $fn :1080
	t_no "$fn bare ipv6" $fn ::1:1080
done

# --- domain validation --------------------------------------------------
t_ok "domain www.cloudflare.com" valid_domain www.cloudflare.com
t_ok "domain a-b.example.org" valid_domain a-b.example.org
t_no "domain ip" valid_domain 1.2.3.4
t_no "domain no dot" valid_domain localhost
t_no "domain leading dot" valid_domain .example.com
t_no "domain trailing dot" valid_domain example.com.
t_no "domain double dot" valid_domain a..example.com
t_no "domain underscore" valid_domain a_b.example.com
t_no "domain space" valid_domain 'a b.example.com'
t_no "domain empty" valid_domain ''
t_no "domain leading hyphen" valid_domain -a.example.com

# --- host:port / api address -------------------------------------------
t_ok "hostport ip" valid_hostport 162.159.198.1:2408
t_ok "hostport v6" valid_hostport '[2606:4700::1]:443'
t_no "hostport none" valid_hostport 162.159.198.1
t_no "hostport bad" valid_hostport 1.2.3.4:99999
t_ok "api ip" valid_api_address 162.159.198.1
t_ok "api name" valid_api_address api.cloudflareclient.com
t_ok "api name:port" valid_api_address api.cloudflareclient.com:443
t_ok "api v6 bracket" valid_api_address '[2606:4700::1]'
t_ok "api v6 bracket port" valid_api_address '[2606:4700::1]:443'
t_no "api bare v6" valid_api_address 2606:4700::1
t_no "api space" valid_api_address 'a b'
t_no "api bad port" valid_api_address example.com:0
t_no "api empty" valid_api_address ''

# --- exit_loc spec / stored value --------------------------------------
# Regression: `aether-ctl set exit_loc off` used to clear the option, and
# init.d then fell back to its "!IR" default, silently re-enabling the policy.
t_ok "exit deny list" valid_exit_loc '!IR'
t_ok "exit deny list multi" valid_exit_loc '!IR,AZ,RU'
t_ok "exit allow list" valid_exit_loc 'DE,SE'
t_ok "exit lowercase" valid_exit_loc 'de,se'
t_ok "exit spaced" valid_exit_loc ' DE, SE '
t_ok "exit equals form" valid_exit_loc '=DE'
t_ok "exit off" valid_exit_loc off
t_ok "exit auto" valid_exit_loc auto
t_ok "exit empty" valid_exit_loc ''
t_no "exit one letter" valid_exit_loc I
t_no "exit bang only" valid_exit_loc '!'
t_no "exit comma only" valid_exit_loc ','
t_no "exit digits" valid_exit_loc '12'
t_no "exit three letters" valid_exit_loc 'IRX'
t_no "exit trailing junk" valid_exit_loc 'IR,1'

t_eq "store off" off normalize_exit_loc off
t_eq "store auto as off" off normalize_exit_loc auto
t_eq "store empty as off" off normalize_exit_loc ''
t_eq "store OFF as off" off normalize_exit_loc OFF
t_eq "store deny list" '!IR' normalize_exit_loc '!IR'
t_eq "store allow list upper" 'DE,SE' normalize_exit_loc 'de,se'
t_eq "store spaced deny list" '!IR,AZ' normalize_exit_loc ' !ir, az '
t_eq "store equals form" '=DE' normalize_exit_loc '=de'

# --- reverse Tor/Psiphon carrier (core refuses only wg and gool-classic) ---
t_ok "reverse masque" reverse_capable masque 2.4.0 modern
t_ok "reverse mim" reverse_capable mim 2.4.0 modern
t_ok "reverse mim without core version" reverse_capable mim '' modern
t_ok "reverse unknown protocol falls back to masque" reverse_capable '' 2.4.0 modern
t_ok "reverse modern gool" reverse_capable gool 2.4.0 modern
t_ok "reverse modern gool, empty mode" reverse_capable gool 2.4.0 ''
t_no "reverse classic gool" reverse_capable gool 2.4.0 classic
t_no "reverse gool on old core" reverse_capable gool 2.2.9 modern
t_no "reverse gool without core version" reverse_capable gool '' modern
t_no "reverse wg" reverse_capable wg 2.4.0 modern
t_no "reverse unknown protocol" reverse_capable foo 2.4.0 modern

# --- manual command line parsing (ctl and watchdog must agree) ----------
for fn in manual_opt wd_manual_opt; do
	t_eq "$fn space form" '127.0.0.1:1900' $fn '--bind 127.0.0.1:1900 --wg' --bind
	t_eq "$fn equals form" '1.2.3.4:5' $fn '--wg --bind=1.2.3.4:5' --bind
	t_eq "$fn multiple flags" 'a:1' $fn '--bind a:1 --bind b:2' --bind
	t_eq "$fn absent" '' $fn '--wg --noize balanced' --bind
	t_eq "$fn socks alias" '127.0.0.1:1901' $fn '--socks 127.0.0.1:1901' --socks
	t_eq "$fn trailing flag no value" '' $fn '--wg --bind' --bind
done

# --- TLS value lists (core 2.4 parses these and exits on a bad one) ------
t_ok "ciphers chrome-ish" valid_tls_list 'ALL:!aPSK:!ECDSA+SHA1:!3DES' ciphers
t_ok "ciphers tls13" valid_tls_list 'TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256' ciphers
t_no "ciphers with comma" valid_tls_list 'ALL,!aPSK' ciphers
t_no "ciphers empty item" valid_tls_list 'ALL::aPSK' ciphers
t_no "ciphers trailing colon" valid_tls_list 'ALL:' ciphers
t_no "ciphers with space" valid_tls_list 'ALL:!a PSK' ciphers
t_ok "groups" valid_tls_list 'P-256:X25519:P-384' groups
t_no "groups with comma" valid_tls_list 'X25519,P-256' groups
t_no "groups empty" valid_tls_list '' groups
t_ok "sigalgs" valid_tls_list 'ecdsa_secp256r1_sha256:rsa_pss_rsae_sha256' sigalgs
t_ok "compression single" valid_tls_list 'brotli' compression
t_ok "compression list" valid_tls_list 'brotli:zlib' compression
t_no "compression comma" valid_tls_list 'brotli,zlib' compression
t_no "compression gzip" valid_tls_list 'gzip' compression
t_no "compression trailing colon" valid_tls_list 'brotli:' compression
t_ok "trust anchors" valid_tls_list '11129.9.1:11129.9.4' trustanchors
t_no "trust anchors comma" valid_tls_list '11129.9.1,11129.9.4' trustanchors
t_no "trust anchors double dot" valid_tls_list '11129..9' trustanchors
t_no "trust anchors leading dot" valid_tls_list '.11129.9' trustanchors
t_no "trust anchors trailing dot" valid_tls_list '11129.9.' trustanchors
t_no "unknown kind" valid_tls_list 'x' bogus

t_ok "padding zero" valid_tls_padding 0
t_ok "padding max" valid_tls_padding 65535
t_ok "padding chrome" valid_tls_padding 6000
t_no "padding too big" valid_tls_padding 65536
t_no "padding text" valid_tls_padding abc
t_no "padding empty" valid_tls_padding ''
t_no "padding space" valid_tls_padding '6000 '

# --- installer HTTPS hint (wrong router clock) --------------------------
HINT_DIR="/tmp/aether-hint-test.$$"
mkdir -p "$HINT_DIR"
printf 'wget: ERROR: cannot verify api.github.com: Issued certificate not yet valid.\n' > "$HINT_DIR/cert.err"
printf 'wget: unable to resolve host address\n' > "$HINT_DIR/net.err"
if [ -n "$(https_hint_text "$HINT_DIR/cert.err")" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: certificate error should produce a clock hint"; fi
if [ -z "$(https_hint_text "$HINT_DIR/net.err")" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: DNS error should not produce a clock hint"; fi
if [ -z "$(https_hint_text "$HINT_DIR/missing.err")" ]; then PASS=$((PASS + 1)); else FAIL=$((FAIL + 1)); echo "FAIL: missing stderr file should not crash or hint"; fi
rm -rf "$HINT_DIR"

echo "helper tests: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
