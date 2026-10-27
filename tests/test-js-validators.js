#!/usr/bin/env node
// Unit tests for the LuCI-side value validators.
//
//   node tests/test-js-validators.js
//
// The router has no node, so this is a development-host check; the shell suites
// (test-static.sh, test-helpers.sh) remain the ones that run on OpenWrt. The
// helpers below are extracted from the shipped view so the tests exercise the
// real code, the same way test-helpers.sh extracts shell functions.

'use strict';

const fs = require('fs');
const path = require('path');

const view = path.join(__dirname, '..', 'files', 'www', 'luci-static', 'resources', 'view', 'aether.js');
const src = fs.readFileSync(view, 'utf8');

// The aetherCheck* helpers are self-contained (no require, no outer state), so a
// body-only recompile is enough to exercise them.
const helpers = {};
const re = /\nfunction (aetherCheck\w+)\(([^)]*)\) \{\n([\s\S]*?)\n\}/g;
let m;

while ((m = re.exec(src)) !== null) {
	const name = m[1];
	const body = m[3];

	// eslint-disable-next-line no-new-func
	helpers[name] = new Function('return function (' + m[2] + ') {\n' + body + '\n}')();
}

let pass = 0;
let fail = 0;

function ok(desc, cond) {
	if (cond) {
		pass++;
	}
	else {
		fail++;
		console.log('FAIL: ' + desc);
	}
}

function accepts(desc, fn, args) {
	ok(desc + ' -> accepted', helpers[fn].apply(null, args) === true);
}

function rejects(desc, fn, args) {
	ok(desc + ' -> rejected', typeof helpers[fn].apply(null, args) === 'string');
}

function loaded(name) {
	ok('helper shipped: ' + name, typeof helpers[name] === 'function');
}

['aetherCheckDomain', 'aetherCheckApiAddress', 'aetherCheckTlsList', 'aetherCheckTlsPadding'].forEach(loaded);

// --- DNS names (masque_sni, api_host, api_sni, ech_domain) ---------------
accepts('domain www.cloudflare.com', 'aetherCheckDomain', ['www.cloudflare.com']);
accepts('domain a-b.example.org', 'aetherCheckDomain', ['a-b.example.org']);
accepts('domain empty (unset)', 'aetherCheckDomain', ['']);
rejects('domain ipv4 literal', 'aetherCheckDomain', ['1.2.3.4']);
rejects('domain no dot', 'aetherCheckDomain', ['localhost']);
rejects('domain underscore', 'aetherCheckDomain', ['a_b.example.com']);
rejects('domain space', 'aetherCheckDomain', ['a b.example.com']);
rejects('domain leading hyphen', 'aetherCheckDomain', ['-a.example.com']);
rejects('domain trailing dot', 'aetherCheckDomain', ['example.com.']);

// --- API address --------------------------------------------------------
accepts('api ipv4', 'aetherCheckApiAddress', ['162.159.198.1']);
accepts('api name', 'aetherCheckApiAddress', ['api.cloudflareclient.com']);
accepts('api name:port', 'aetherCheckApiAddress', ['api.cloudflareclient.com:443']);
accepts('api v6 bracket', 'aetherCheckApiAddress', ['[2606:4700::1]']);
accepts('api v6 bracket port', 'aetherCheckApiAddress', ['[2606:4700::1]:443']);
rejects('api bare v6', 'aetherCheckApiAddress', ['2606:4700::1']);
rejects('api port 0', 'aetherCheckApiAddress', ['example.com:0']);
rejects('api port high', 'aetherCheckApiAddress', ['example.com:70000']);
rejects('api space', 'aetherCheckApiAddress', ['a b']);
rejects('api empty', 'aetherCheckApiAddress', ['']);

// --- TLS lists (colon separated, one alphabet per kind) -----------------
accepts('ciphers chrome default', 'aetherCheckTlsList', ['ALL:!aPSK:!ECDSA+SHA1:!3DES', 'ciphers']);
accepts('ciphers tls13', 'aetherCheckTlsList', ['TLS_AES_128_GCM_SHA256:TLS_CHACHA20_POLY1305_SHA256', 'ciphers']);
rejects('ciphers comma', 'aetherCheckTlsList', ['ALL,!aPSK', 'ciphers']);
rejects('ciphers empty item', 'aetherCheckTlsList', ['ALL::aPSK', 'ciphers']);
rejects('ciphers trailing colon', 'aetherCheckTlsList', ['ALL:', 'ciphers']);
accepts('groups', 'aetherCheckTlsList', ['P-256:X25519:P-384', 'groups']);
rejects('groups comma', 'aetherCheckTlsList', ['X25519,P-256', 'groups']);
accepts('sigalgs', 'aetherCheckTlsList', ['ecdsa_secp256r1_sha256:rsa_pss_rsae_sha256', 'sigalgs']);
accepts('compression single', 'aetherCheckTlsList', ['brotli', 'compression']);
accepts('compression list', 'aetherCheckTlsList', ['brotli:zlib', 'compression']);
rejects('compression comma', 'aetherCheckTlsList', ['brotli,zlib', 'compression']);
rejects('compression gzip', 'aetherCheckTlsList', ['gzip', 'compression']);
accepts('trust anchors', 'aetherCheckTlsList', ['11129.9.1:11129.9.4', 'trustanchors']);
rejects('trust anchors comma', 'aetherCheckTlsList', ['11129.9.1,11129.9.4', 'trustanchors']);
rejects('trust anchors double dot', 'aetherCheckTlsList', ['11129..9', 'trustanchors']);

// --- TLS server padding -------------------------------------------------
accepts('padding zero', 'aetherCheckTlsPadding', ['0']);
accepts('padding max', 'aetherCheckTlsPadding', ['65535']);
accepts('padding chrome', 'aetherCheckTlsPadding', ['6000']);
rejects('padding too big', 'aetherCheckTlsPadding', ['65536']);
rejects('padding text', 'aetherCheckTlsPadding', ['abc']);
rejects('padding empty', 'aetherCheckTlsPadding', ['']);
rejects('padding space', 'aetherCheckTlsPadding', ['6000 ']);

console.log('js validator tests: ' + pass + ' passed, ' + fail + ' failed');
process.exit(fail === 0 ? 0 : 1);
