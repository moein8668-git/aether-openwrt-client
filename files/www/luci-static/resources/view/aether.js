/*
 * luci-app-aether — LuCI Web Interface for Aether VPN
 *
 * Uses built-in ubus objects (service / rc / uci / file) instead of a
 * custom shell rpcd handler. On OpenWrt 25.12.5 shell handlers under
 * /usr/libexec/rpcd may register as ubus objects with zero methods.
 */
'use strict';
'require form';
'require rpc';
'require uci';
'require ui';
'require view';

/* Obfuscation profiles from Aether core guide — depend on protocol. */
var AETHER_PROFILES = {
	masque: {
		firewall: 'Firewall (recommended)',
		gfw: 'GFW',
		off: 'Off'
	},
	wg: {
		balanced: 'Balanced (recommended)',
		aggressive: 'Aggressive',
		light: 'Light',
		off: 'Off'
	},
	gool: {
		balanced: 'Balanced (recommended)',
		aggressive: 'Aggressive',
		light: 'Light',
		off: 'Off'
	}
};

function aetherProfileLabels(protocol) {
	return AETHER_PROFILES[protocol] || AETHER_PROFILES.masque;
}

function aetherProfileDefault(protocol) {
	return (protocol === 'wg' || protocol === 'gool') ? 'balanced' : 'firewall';
}

function aetherSyncProfileChoices(profileOpt, section_id, protocol) {
	var labels = aetherProfileLabels(protocol);
	var keys = Object.keys(labels);
	var def = aetherProfileDefault(protocol);
	var uiEl, cur;

	profileOpt.keylist = keys.slice();
	profileOpt.vallist = keys.map(function(k) { return labels[k]; });

	try {
		uiEl = profileOpt.getUIElement(section_id);
	}
	catch (e) {
		uiEl = null;
	}

	if (!uiEl)
		return;

	cur = uiEl.getValue();
	if (cur == null || cur === '' || !labels.hasOwnProperty(cur))
		cur = def;

	if (typeof uiEl.clearChoices === 'function' && typeof uiEl.addChoices === 'function') {
		uiEl.clearChoices(true);
		uiEl.addChoices(keys, labels);
		uiEl.setValue(cur);
		return;
	}

	/* Native <select> fallback */
	var node = uiEl.node || uiEl;
	var select = (node && node.tagName === 'SELECT') ? node
		: (node && node.querySelector ? node.querySelector('select') : null);
	if (select) {
		while (select.firstChild)
			select.removeChild(select.firstChild);
		keys.forEach(function(k) {
			select.appendChild(E('option', { value: k }, labels[k]));
		});
		select.value = cur;
	}
}

function aetherSetOptionDisabled(opt, section_id, disabled) {
	var uiEl = null, node = null, controls = [];

	try {
		uiEl = opt.getUIElement(section_id);
	}
	catch (e) {
		uiEl = null;
	}

	node = uiEl ? (uiEl.node || uiEl) : document.getElementById(opt.cbid(section_id));
	if (!node)
		return;

	if (node.matches && node.matches('input, select, textarea, button, .cbi-dropdown'))
		controls.push(node);

	if (node.querySelectorAll) {
		node.querySelectorAll('input, select, textarea, button, .cbi-dropdown').forEach(function(ctrl) {
			controls.push(ctrl);
		});
	}

	controls.forEach(function(ctrl) {
		if (disabled)
			ctrl.setAttribute('disabled', 'disabled');
		else
			ctrl.removeAttribute('disabled');

		if ('disabled' in ctrl)
			ctrl.disabled = disabled;
	});
}

function aetherSyncMasqueOptions(options, section_id, protocol) {
	var disabled = (protocol !== 'masque');
	options.forEach(function(opt) {
		aetherSetOptionDisabled(opt, section_id, disabled);
	});
}

var callServiceList = rpc.declare({
	object: 'service',
	method: 'list',
	params: [ 'name' ],
	expect: {}
});

var callRCInit = rpc.declare({
	object: 'rc',
	method: 'init',
	params: [ 'name', 'action' ],
	expect: {}
});

var callUCIGet = rpc.declare({
	object: 'uci',
	method: 'get',
	params: [ 'config', 'section', 'option' ],
	expect: {}
});

var callFileExec = rpc.declare({
	object: 'file',
	method: 'exec',
	params: [ 'command', 'params' ],
	expect: {}
});

function extractFromLogs(logs, pattern) {
	if (!logs) return '';
	var m = logs.match(pattern);
	return m ? m[1] : '';
}

function getServiceStatus() {
	return Promise.all([
		callServiceList('aether').then(function(res) {
			try {
				var inst = res.aether.instances.instance1;
				return { running: !!inst.running, pid: inst.pid, command: inst.command };
			} catch (e) {
				return { running: false };
			}
		}).catch(function() {
			return { running: false };
		}),
		callUCIGet('aether', 'main', 'enabled').then(function(r) {
			return (r && r.value != null) ? String(r.value).replace(/'/g, '') : '0';
		}).catch(function() { return '0'; }),
		callUCIGet('aether', 'main', 'protocol').then(function(r) {
			return (r && r.value) ? String(r.value).replace(/'/g, '') : 'masque';
		}).catch(function() { return 'masque'; }),
		callFileExec('logread', [ '-e', 'aether', '-l', '30' ]).then(function(r) {
			return (r && r.stdout) ? r.stdout : '';
		}).catch(function() { return ''; }),
		callFileExec('/usr/bin/aether', [ '--version' ]).then(function(r) {
			return (r && r.stdout) ? String(r.stdout).trim() : '';
		}).catch(function() { return ''; })
	]).then(function(r) {
		var svc = r[0], logs = r[3], version = r[4];
		return {
			running: svc.running,
			pid: svc.pid,
			command: svc.command,
			enabled: r[1],
			protocol: r[2],
			version: version.replace(/^aether\s+/i, ''),
			endpoint: extractFromLogs(logs, /using cloudflare edge ([0-9.:]+)/),
			transport: extractFromLogs(logs, /MASQUE transport: ([^\s]+)/),
			socks_addr: extractFromLogs(logs, /socks5 (?:server )?listening on ([^\s]+)/),
			obfuscation: extractFromLogs(logs, /obfuscation profile: (\w+)/),
			scan_mode: extractFromLogs(logs, /scan mode: (\w+)/),
			identity: extractFromLogs(logs, /device=([^\s]+)/),
			logs: logs
		};
	});
}

function doServiceAction(action) {
	return function() {
		var btn = this;
		btn.disabled = true;
		btn.value = '...';
		callRCInit('aether', action).then(function() {
			setTimeout(function() { location.reload(); }, 3000);
		}).catch(function() {
			btn.disabled = false;
			btn.value = action.charAt(0).toUpperCase() + action.slice(1);
		});
	};
}

function doTestConnection(host) {
	return function() {
		var btn = this;
		var resultEl = document.getElementById('test-result-' + host);
		btn.disabled = true;
		btn.value = 'Testing...';
		if (resultEl) {
			resultEl.textContent = 'Connecting...';
			resultEl.style.color = '#888';
		}

		callFileExec('/usr/bin/aether-ctl', [ 'test', host ]
		).then(function(r) {
			var output = (r && r.stdout) ? r.stdout : '';
			var errput = (r && r.stderr) ? r.stderr : '';
			var combined = output + ' ' + errput;
			// New format: "OK <http_code> <ms>ms" or "FAILED <ms>ms"
			var okMatch = combined.match(/OK\s+(\d+)\s+(\d+)ms/i);
			var failMatch = combined.match(/FAILED\s+(\d+)ms/i);
			if (okMatch) {
				var info = 'HTTP ' + okMatch[1] + ' \u2014 ' + okMatch[2] + 'ms';
				if (resultEl) {
					resultEl.textContent = info;
					resultEl.style.color = '#2ecc71';
				}
			} else if (failMatch) {
				if (resultEl) {
					resultEl.textContent = 'Failed \u2014 ' + failMatch[1] + 'ms';
					resultEl.style.color = '#e74c3c';
				}
			} else {
				if (resultEl) {
					resultEl.textContent = 'Failed';
					resultEl.style.color = '#e74c3c';
				}
			}
		}).catch(function() {
			if (resultEl) {
				resultEl.textContent = 'Error';
				resultEl.style.color = '#e74c3c';
			}
		}).finally(function() {
			btn.disabled = false;
			btn.value = host;
		});
	};
}


return view.extend({
	load: function() {
		return {};
	},

	render: function() {
		var el = E('div', {});

		return getServiceStatus().then(function(st) {
			var tbl = E('table', { 'class': 'table' });

			function row(label, val) {
				if (val == null || val === '') return;
				tbl.appendChild(E('tr', { 'class': 'tr' }, [
					E('td', { 'class': 'td', 'style': 'width:160px;font-weight:600' }, label),
					E('td', { 'class': 'td' }, val)
				]));
			}

			var color = st.running ? '#2ecc71' : '#e74c3c';
			row('State', E('span', {
				'style': 'font-weight:bold;color:' + color
			}, st.running ? 'Running' : 'Stopped'));

			if (st.running) {
				if (st.version) row('Version', st.version);
				if (st.pid) row('PID', String(st.pid));
				if (st.endpoint) row('Endpoint', E('code', {}, st.endpoint));
				if (st.transport) row('Transport', 'MASQUE / ' + st.transport);
				if (st.obfuscation) row('Obfuscation', st.obfuscation);
				if (st.scan_mode) row('Scan Mode', st.scan_mode);
				if (st.socks_addr) row('SOCKS5 Proxy', E('code', {}, st.socks_addr));
				if (st.identity) {
					row('Device ID', E('code', {
						'style': 'font-size:11px;word-break:break-all'
					}, st.identity));
				}
			} else {
				row('Info', 'Service is not running. Click Start to begin.');
			}

			var btns = E('div', {
				'style': 'margin-top:10px;display:flex;gap:8px;align-items:center;flex-wrap:wrap'
			});

			if (st.running) {
				btns.appendChild(E('input', {
					'type': 'button',
					'class': 'cbi-button cbi-button-remove',
					'value': 'Stop',
					'click': doServiceAction('stop')
				}));
				btns.appendChild(E('input', {
					'type': 'button',
					'class': 'cbi-button cbi-button-reset',
					'value': 'Restart',
					'click': doServiceAction('restart')
				}));
			} else {
				btns.appendChild(E('input', {
					'type': 'button',
					'class': 'cbi-button cbi-button-apply',
					'value': 'Start',
					'click': doServiceAction('start')
				}));
			}

			btns.appendChild(E('span', {
				'style': 'font-size:12px;color:#888;margin-left:8px'
			}, 'Start/Stop controls the running tunnel. "Enable on Boot" below controls auto-start on reboot.'));

			el.appendChild(E('div', { 'class': 'cbi-section' }, [
				E('h3', { 'style': 'margin-top:0' }, 'Status'),
				tbl,
				btns
			]));

			// --- Connection Test Section ---
			var testSection = E('div', { 'class': 'cbi-section' }, [
				E('h3', { 'style': 'margin-top:0' }, 'Connection Test'),
				E('p', { 'style': 'margin:4px 0 10px 0;color:#666;font-size:13px' },
					'Test if the tunnel can reach external services through the SOCKS5 proxy.')
			]);

			var testHosts = ['google.com', 'youtube.com', 'github.com', 'telegram.org'];
			var testRow = E('div', {
				'style': 'display:flex;gap:10px;align-items:center;flex-wrap:wrap'
			});

			testHosts.forEach(function(host) {
				var wrapper = E('div', {
					'style': 'display:flex;align-items:center;gap:6px'
				});

				var btn = E('input', {
					'type': 'button',
					'class': 'cbi-button cbi-button-apply',
					'value': host,
					'click': doTestConnection(host)
				});

				var result = E('span', {
					'id': 'test-result-' + host,
					'style': 'font-size:13px;color:#888;min-width:100px'
				}, '');

				wrapper.appendChild(btn);
				wrapper.appendChild(result);
				testRow.appendChild(wrapper);
			});

			testSection.appendChild(testRow);
			el.appendChild(testSection);

			// --- Live Logs Section ---
			var logSection = E('div', { 'class': 'cbi-section' }, [
				E('h3', { 'style': 'margin-top:0' }, 'Live Logs'),
				E('p', { 'style': 'margin:4px 0 10px 0;color:#666;font-size:13px' },
					'Auto-updating Aether log output. Streaming in real-time.')
			]);

			var logContent = E('pre', {
				'id': 'aether-log-content',
				'style': 'background:#1a1a2e;color:#e0e0e0;padding:12px;border-radius:6px;max-height:400px;overflow-y:auto;font-size:12px;line-height:1.5;white-space:pre-wrap;word-break:break-all;margin:0'
			}, st.logs || '(no logs)');

			// Auto-scroll toggle
			var autoScroll = true;
			var autoScrollLabel = E('label', {
				'style': 'font-size:13px;color:#666;display:flex;align-items:center;gap:6px;cursor:pointer'
			});
			var autoScrollCheckbox = E('input', {
				'type': 'checkbox',
				'checked': true,
				'style': 'margin:0',
				'click': function() { autoScroll = autoScrollCheckbox.checked; }
			});
			autoScrollLabel.appendChild(autoScrollCheckbox);
			autoScrollLabel.appendChild(document.createTextNode('Auto-scroll'));

			// Pause/resume button
			var isPaused = false;
			var pauseBtn = E('input', {
				'type': 'button',
				'class': 'cbi-button cbi-button-reset',
				'value': 'Pause',
				'click': function() {
					isPaused = !isPaused;
					pauseBtn.value = isPaused ? 'Resume' : 'Pause';
					pauseBtn.className = isPaused ? 'cbi-button cbi-button-apply' : 'cbi-button cbi-button-reset';
					if (!isPaused) {
						fetchLatestLogs();
					}
				}
			});

			// Clear button
			var clearBtn = E('input', {
				'type': 'button',
				'class': 'cbi-button',
				'value': 'Clear',
				'click': function() {
					logContent.textContent = '';
				}
			});

			var logControls = E('div', {
				'style': 'display:flex;justify-content:space-between;align-items:center;margin-bottom:8px;gap:8px'
			}, [ autoScrollLabel, E('div', { 'style': 'display:flex;gap:6px' }, [ pauseBtn, clearBtn ]) ]);

			logSection.appendChild(logControls);
			logSection.appendChild(logContent);
			el.appendChild(logSection);

			// --- Real live log streaming ---
			var logPollTimer = null;

			function fetchLatestLogs() {
				if (isPaused) return;
				callFileExec('logread', [ '-e', 'aether', '-l', '50' ]).then(function(r) {
					var logs = (r && r.stdout) ? r.stdout : '';
					if (!logs) return;

					var currentText = logContent.textContent || '';
					if (currentText === '(no logs)' || currentText === '') {
						logContent.textContent = logs;
						return;
					}

					/* Find lines that appeared AFTER the last line we already have.
					   Take the last non-empty line of the current buffer and
					   look for it in the new logread output.  Everything after
					   that position is new.  If the last line is NOT found (log
					   rotated or buffer exceeded), replace the entire buffer. */
					var currentLines = currentText.split('\n');
					var lastLine = '';
					for (var i = currentLines.length - 1; i >= 0; i--) {
						if (currentLines[i].trim() !== '') {
							lastLine = currentLines[i];
							break;
						}
					}

					if (!lastLine) {
						logContent.textContent = logs;
						return;
					}

					var newLines = logs.split('\n');
					var matchPos = -1;
					for (var j = 0; j < newLines.length; j++) {
						if (newLines[j] === lastLine) {
							matchPos = j;
						}
					}

					if (matchPos >= 0 && matchPos < newLines.length - 1) {
						/* append everything after the matched line */
						var tail = newLines.slice(matchPos + 1).join('\n');
						if (tail.trim() !== '') {
							if (logContent.textContent.slice(-1) !== '\n') {
								logContent.textContent += '\n';
							}
							logContent.textContent += tail;
							if (tail.slice(-1) !== '\n') {
								logContent.textContent += '\n';
							}
						}
					} else if (matchPos >= 0) {
						/* last line matches and nothing after it — no new logs */
						return;
					} else {
						/* last line not found — log rotated or buffer exceeded,
						   replace entire content with fresh window */
						logContent.textContent = logs;
					}

					/* Trim to last 500 lines */
					var allLines = logContent.textContent.split('\n');
					if (allLines.length > 500) {
						logContent.textContent = allLines.slice(-500).join('\n');
					}

					if (autoScroll) {
						logContent.scrollTop = logContent.scrollHeight;
					}
				}).catch(function() {});
			}

			// Poll every 2 seconds for new logs
			logPollTimer = setInterval(fetchLatestLogs, 2000);

			// Clean up timer when leaving the page
			window.addEventListener('beforeunload', function() {
				if (logPollTimer) clearInterval(logPollTimer);
			});

			el.appendChild(E('hr', {
				'style': 'margin:12px 0;border:none;border-top:1px solid #ddd'
			}));

			var m = new form.Map('aether', '',
				'Configure Aether tunnel settings below. Click "Save & Apply" to persist changes.');
			var s, o;

			s = m.section(form.NamedSection, 'main', 'aether', 'Basic Settings');
			s.anonymous = true;

			o = s.option(form.Flag, 'enabled', 'Enable on Boot',
				'Auto-start Aether when the router boots');
			o.default = '0';
			o.rmempty = false;

			o = s.option(form.ListValue, 'protocol', 'Protocol');
			o.value('masque', 'MASQUE (recommended)');
			o.value('wg', 'WireGuard');
			o.value('gool', 'WARP-in-WARP');
			o.default = 'masque';
			var protocolOpt = o;
			var masqueOptionOpts = [];

			o = s.option(form.Value, 'socks_listen', 'SOCKS5 Listen Address');
			o.default = '0.0.0.0:1819';
			o.datatype = 'ipaddrport';
			o.rmempty = false;

			s = m.section(form.NamedSection, 'main', 'aether', 'Network');

			o = s.option(form.ListValue, 'scan_mode', 'Scan Mode',
				'turbo=fastest, balanced=default, thorough=best quality, stealth=quietest, ironclad=real tunnel test');
			o.value('turbo', 'Turbo');
			o.value('balanced', 'Balanced (default)');
			o.value('thorough', 'Thorough');
			o.value('stealth', 'Stealth');
			o.value('ironclad', 'Ironclad (real tunnel test)');
			o.default = 'balanced';

			o = s.option(form.ListValue, 'ip_version', 'IP Version');
			o.value('ipv4', 'IPv4 only');
			o.value('ipv6', 'IPv6 only');
			o.value('both', 'Both');
			o.default = 'ipv4';

			o = s.option(form.Value, 'peer', 'Force Peer',
				'ip:port, or leave empty for auto-scan');
			o.rmempty = true;

			s = m.section(form.NamedSection, 'main', 'aether', 'Obfuscation');

			o = s.option(form.ListValue, 'obfuscation_profile', 'Profile',
				'Choices change with Protocol (MASQUE vs WireGuard/gool)');
			o.rmempty = false;
			o.value('firewall', 'Firewall (recommended)');
			o.value('gfw', 'GFW');
			o.value('off', 'Off');
			o.value('balanced', 'Balanced (recommended)');
			o.value('aggressive', 'Aggressive');
			o.value('light', 'Light');
			o.default = 'firewall';
			var profileOpt = o;
			o.cfgvalue = function(section_id) {
				var proto = uci.get('aether', section_id, 'protocol') || 'masque';
				var v = uci.get('aether', section_id, 'obfuscation_profile');
				var labels = aetherProfileLabels(proto);
				if (!v || !labels.hasOwnProperty(v))
					return aetherProfileDefault(proto);
				return v;
			};
			o.renderWidget = function(section_id, option_index, cfgvalue) {
				var proto = 'masque';
				try {
					proto = protocolOpt.formvalue(section_id) || protocolOpt.cfgvalue(section_id) || 'masque';
				}
				catch (e) {
					proto = uci.get('aether', section_id, 'protocol') || 'masque';
				}
				var labels = aetherProfileLabels(proto);
				var keys = Object.keys(labels);
				this.keylist = keys.slice();
				this.vallist = keys.map(function(k) { return labels[k]; });
				if (cfgvalue == null || !labels.hasOwnProperty(cfgvalue))
					cfgvalue = aetherProfileDefault(proto);
				return new ui.Select(cfgvalue, labels, {
					id: this.cbid(section_id),
					sort: keys,
					widget: this.widget,
					optional: this.optional,
					validate: (typeof this.getValidator === 'function') ? this.getValidator(section_id) : null,
					disabled: (this.readonly != null) ? this.readonly : this.map.readonly
				}).render();
			};

			protocolOpt.onchange = function(ev, section_id, value) {
				var proto = value || 'masque';
				aetherSyncProfileChoices(profileOpt, section_id, proto);
				aetherSyncMasqueOptions(masqueOptionOpts, section_id, proto);
			};

			s = m.section(form.NamedSection, 'main', 'aether', 'MASQUE Options');

			o = s.option(form.Flag, 'http2_mode', 'HTTP/2 Mode',
				'Enable if UDP/QUIC is blocked');
			o.default = '0';
			masqueOptionOpts.push(o);

			o = s.option(form.Value, 'h2_peer', 'H2 Peer',
				'Manual destination for h2 mode (ip:port), leave empty for auto');
			o.rmempty = true;
			masqueOptionOpts.push(o);

			o = s.option(form.Flag, 'fragment_tls', 'TLS Fragmentation',
				'Fragment ClientHello (HTTP/2 only)');
			o.default = '0';
			masqueOptionOpts.push(o);

			o = s.option(form.Value, 'fragment_size', 'Fragment Size');
			o.default = '16-32';
			masqueOptionOpts.push(o);

			o = s.option(form.Value, 'fragment_delay', 'Fragment Delay (ms)');
			o.default = '2-10';
			masqueOptionOpts.push(o);

			s = m.section(form.NamedSection, 'main', 'aether', 'Advanced');

			o = s.option(form.ListValue, 'log_level', 'Log Level');
			o.value('error', 'Error');
			o.value('warn', 'Warning');
			o.value('info', 'Info');
			o.value('debug', 'Debug');
			o.default = 'info';

			o = s.option(form.Value, 'keepalive', 'Keepalive (s)');
			o.default = '5';
			o.datatype = 'min(1)';
			o.depends('protocol', 'wg');
			o.depends('protocol', 'gool');

			o = s.option(form.Value, 'reconnect_secs', 'Reconnect Delay (s)',
				'Delay before auto-reconnect after tunnel drops');
			o.default = '2';
			o.datatype = 'min(1)';

			o = s.option(form.Value, 'validate_secs', 'Validation Timeout (s)',
				'Seconds to wait for data-plane probe before giving up on a gateway');
			o.default = '10';
			o.datatype = 'min(1)';

			o = s.option(form.Flag, 'quick_reconnect', 'Quick Reconnect',
				'Always reuse last known-good gateway without asking');
			o.default = '0';

			o = s.option(form.Flag, 'no_data_check', 'Skip Data Validation',
				'Trust gateway after handshake only (faster but less reliable)');
			o.default = '0';

			o = s.option(form.Value, 'config_path', 'Config Path');
			o.default = '/etc/aether/aether.toml';
			o.readonly = true;

			return m.render().then(function(formNode) {
				el.appendChild(formNode);
				var proto = 'masque';
				try {
					proto = protocolOpt.formvalue('main') || protocolOpt.cfgvalue('main') || 'masque';
				}
				catch (e) {
					proto = uci.get('aether', 'main', 'protocol') || 'masque';
				}
				aetherSyncProfileChoices(profileOpt, 'main', proto);
				aetherSyncMasqueOptions(masqueOptionOpts, 'main', proto);
				return el;
			});
		});
	}
});
