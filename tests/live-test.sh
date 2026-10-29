#!/bin/sh
# Live lab test harness (runs ON the router, BusyBox ash). Not part of CI.
#
#   sh live-test.sh case <name> <wait-secs> [uci-option=value ...]
#
# Applies the UCI options on top of a clean baseline, restarts the service,
# waits for the readiness markers in the core log, then sends one request
# through the SOCKS5 port and records the result under /tmp/live/<name>.*
# Output: one "RESULT <name> PASS|FAIL ..." line plus the evidence files.

OUT=/tmp/live
mkdir -p "$OUT"

baseline() {
	# Options this harness may touch are reset so cases cannot leak into each other.
	for o in protocol gool_mode gool_peer http2_mode fragment_tls fragment_size fragment_delay \
		scan_mode masque_sni api_address api_host api_sni tls_verify ech ech_dns ech_domain \
		upstream_proxy exit_loc peer obfuscation_profile wiw_outer wiw_inner \
		mim_outer mim_inner tor_mode psiphon_mode no_profile_retry quick_reconnect \
		tls_ciphers tls13_ciphers tls_groups tls_key_shares tls_sigalgs tls_cert_compression tls_alps \
		tls_trust_anchors tls_server_padding disable_grease enable_grease_sigalgs enable_ech_grease \
		disable_ocsp_stapling disable_sct disable_session_ticket disable_extension_permutation \
		tor_bind psiphon_bind; do
		uci -q delete aether.main.$o
	done
	uci set aether.main.protocol=masque
	uci set aether.main.socks_listen=127.0.0.1:1819
	uci set aether.main.exit_loc=!IR
	uci commit aether
}

run_case() {
	name="$1"; wait_s="$2"; shift 2
	/etc/init.d/aether stop >/dev/null 2>&1
	killall aether 2>/dev/null
	sleep 1
	baseline
	for kv in "$@"; do
		uci set "aether.main.$kv" || { echo "RESULT $name FAIL uci-set-$kv"; return 1; }
	done
	uci commit aether
	mark="CASE-$name-$$-$(date +%s)"
	logger -t aether-test "$mark"
	t0=$(date +%s)
	/etc/init.d/aether start >/dev/null 2>&1
	ready=0
	i=0
	while [ "$i" -lt "$wait_s" ]; do
		sleep 1
		i=$((i + 1))
		if logread | sed -n "/$mark/,\$p" | grep -q 'socks5 server listening on'; then
			ready=1
			break
		fi
	done
	t1=$(date +%s)
	logread | sed -n "/$mark/,\$p" | grep -v "$mark" > "$OUT/$name.log"
	validated=0
	grep -q 'tunnel validated' "$OUT/$name.log" && validated=1
	trace=""
	if [ "$ready" -eq 1 ]; then
		trace="$(curl -s -m 25 --socks5-hostname 127.0.0.1:1819 https://www.cloudflare.com/cdn-cgi/trace 2>&1 | tr '\n' ' ')"
	fi
	printf '%s\n' "$trace" > "$OUT/$name.trace"
	case "$trace" in
		*warp=on*|*warp=plus*) warp=on ;;
		*warp=off*) warp=off ;;
		*) warp=none ;;
	esac
	pid="$(ubus call service list '{"name":"aether"}' 2>/dev/null | jsonfilter -e '@.aether.instances.core.pid' 2>/dev/null)"
	ubus call service list '{"name":"aether"}' 2>/dev/null | jsonfilter -e '@.aether.instances.core.command[*]' 2>/dev/null | tr '\n' ' ' > "$OUT/$name.cmd"
	echo "RESULT $name ready=$ready validated=$validated warp=$warp secs=$((t1 - t0)) pid=${pid:-none} trace=[$(echo "$trace" | sed 's/ \(visit_scheme\|http\|uag\|tls\|sni\|gateway\|rbi\|kex\|colo\|fl\|h\|ts\)=[^ ]*//g')]"
}

case "${1:-}" in
	case) shift; run_case "$@" ;;
	baseline) baseline ;;
	*) echo "usage: $0 case <name> <wait> [opt=val ...] | baseline"; exit 2 ;;
esac
