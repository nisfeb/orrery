// orrery's page: a reader with buttons over /apps/orrery/api. Pure render
// functions first (tested under node), then the app that wires them to
// the API and the beacon stream.
(function () {
  'use strict';
  var API = '/apps/orrery/api';
  var KEEP = '/grubbery/api/keep/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/beacon/rev';

  // ---- render, pure ----
  function esc(s) {
    return String(s).replace(/[<>&"']/g, function (c) {
      return { '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;' }[c];
    });
  }
  function fmtValue(v) {
    if (v === null || v === undefined) return '<span class="muted">cleared</span>';
    if (typeof v === 'object' && !Array.isArray(v) && typeof v.ref === 'string') {
      return '<a href="#body/' + esc(v.ref) + '">' + esc(v.ref) + '</a>';
    }
    if (typeof v === 'string') return esc(v);
    return esc(JSON.stringify(v));
  }
  function fmtTime(t) { return t ? esc(String(t).replace('T', ' ').replace('Z', '')) : ''; }
  function source(s) { s = s || {}; return '<code>' + esc(s.kind || '') + '</code> ' + esc(s.id || ''); }
  // an inline run of ids: linked by name when the state is at hand, the
  // id on hover
  function links(ids, byId) {
    return (ids || []).map(function (b) {
      var known = byId && byId[b];
      return '<a href="#body/' + esc(b) + '" title="' + esc(b) + '">' + esc(known && known.name ? known.name : b) + '</a>';
    }).join(', ');
  }
  function badge(s) { return '<span class="badge ' + esc(s) + '">' + esc(s) + '</span>'; }
  // a table: its head row, then labelled cells, so that on a phone, where
  // the table stacks one row per card, each cell still says which column
  // it came from
  function thead(cols) { return '<table><thead><tr>' + cols.map(function (c) { return '<th scope="col">' + esc(c) + '</th>'; }).join('') + '</tr></thead><tbody>'; }
  function cell(label, html) { return '<td data-label="' + esc(label) + '">' + html + '</td>'; }

  // a situation's phase from its times: closed or cancelled when status says
  // so, over once its (actual or scheduled) end has passed, under way once its
  // start has, upcoming while its start is ahead; stored status never says
  // "under way" or "over", the clock does
  function timeOf(b, name) {
    var v = b && b.attrs && b.attrs[name];
    return v && !Array.isArray(v) && typeof v.value === 'string' ? v.value : '';
  }
  function phase(b, now) {
    var st = timeOf(b, 'status');
    if (st === 'closed' || st === 'cancelled') return st;
    var end = timeOf(b, 'ended') || timeOf(b, 'ends');
    var start = timeOf(b, 'started') || timeOf(b, 'starts');
    now = now || new Date().toISOString();
    if (end && end <= now) return 'over';
    if (start && start <= now) return 'under way';
    if (start) return 'upcoming';
    return st || 'open';
  }
  function index(state) {
    var byId = Object.create(null);
    ((state && state.bodies) || []).forEach(function (b) { byId[b.id] = b; });
    return byId;
  }
  // a list of situations, wherever one is shown: cards by name with the
  // phase and start, the id as subtext, soonest first (a start in the past
  // is ongoing and comes before one still ahead), then the ones with the
  // most open actions, then by name; never in id order and never a run of
  // bare ids. Without the state each card is named by its id.
  function situationCards(ids, state) {
    var byId = index(state);
    var pending = Object.create(null);
    ((state && state.actions) || []).forEach(function (a) { (a.about || []).forEach(function (id) { pending[id] = (pending[id] || 0) + 1; }); });
    function startOf(b) { return timeOf(b, 'started') || timeOf(b, 'starts'); }
    var open = (ids || []).map(function (id) { return byId[id] || { id: id, name: id, attrs: {} }; });
    open.sort(function (a, b) {
      var sa = startOf(a), sb = startOf(b);
      if (sa !== sb) { if (!sa) return 1; if (!sb) return -1; return sa < sb ? -1 : 1; }
      var na = pending[a.id] || 0, nb = pending[b.id] || 0;
      if (na !== nb) return nb - na;
      return (a.name || a.id).toLowerCase() < (b.name || b.id).toLowerCase() ? -1 : 1;
    });
    var out = '<div class="bodies">';
    open.forEach(function (b) {
      var n = pending[b.id] || 0;
      out += '<a href="#body/' + esc(b.id) + '">' + esc(b.name || b.id) +
        ' <span class="muted">' + esc(phase(b)) + (startOf(b) ? ', ' + fmtTime(startOf(b)) : '') + '</span>' +
        (n ? ' <span class="muted">' + n + ' open action' + (n === 1 ? '' : 's') + '</span>' : '') +
        '<span class="id">' + esc(b.id) + '</span></a>';
    });
    return out + '</div>';
  }

  function bodies(state) {
    var byKind = Object.create(null);
    (state.bodies || []).forEach(function (b) { (byKind[b.kind] = byKind[b.kind] || []).push(b); });
    var kinds = Object.keys(byKind).sort();
    var out = '<h1>Bodies</h1>';
    if (state.situations && state.situations.length) {
      out += '<div class="card"><h2>Open situations</h2>' + situationCards(state.situations, state) + '</div>';
    }
    function card(b) {
      var n = Object.keys(b.attrs || {}).length;
      return '<a href="#body/' + esc(b.id) + '">' + esc(b.name || b.id) +
        (b.ship ? ' <span class="muted">' + esc(b.ship) + '</span>' : '') +
        '<span class="id">' + esc(b.id) + (n ? ' &middot; ' + n + ' attr' + (n === 1 ? '' : 's') : '') + '</span></a>';
    }
    function closed(b) {
      var st = b.attrs && b.attrs.status;
      return !!(st && !Array.isArray(st) && st.value === 'closed');
    }
    kinds.forEach(function (k) {
      var all = byKind[k].sort(function (a, b) { return a.id < b.id ? -1 : 1; });
      // a situation that is over stays on the ship with its timeline, but it
      // is not something to look at every day: it folds under "past"
      var past = k === 'situation' ? all.filter(closed) : [];
      var live = k === 'situation' ? all.filter(function (b) { return !closed(b); }) : all;
      out += '<h2>' + esc(k) + '</h2><div class="bodies">';
      live.forEach(function (b) { out += card(b); });
      out += '</div>';
      if (past.length) {
        out += '<details class="past"><summary>past situations (' + past.length + ')</summary><div class="bodies">';
        past.forEach(function (b) { out += card(b); });
        out += '</div></details>';
      }
    });
    if (!kinds.length) out += '<p class="muted">Nothing observed yet.</p>';
    return out;
  }

  // the state rides along for the names, phases and open-action counts of
  // the situations the body is involved in
  function body(v, state) {
    var out = '<h1>' + esc(v.name || v.id) + ' <span class="muted">' + esc(v.id) + '</span></h1>';
    if (v.kind === 'situation') {
      var ph = phase(v), start = timeOf(v, 'started') || timeOf(v, 'starts'), end = timeOf(v, 'ended') || timeOf(v, 'ends');
      out += '<p class="phase">' + esc(ph) +
        (start ? ' <span class="muted">' + (timeOf(v, 'started') ? 'started ' : 'starts ') + fmtTime(start) + '</span>' : '') +
        (end ? ' <span class="muted">' + (timeOf(v, 'ended') ? 'ended ' : 'ends ') + fmtTime(end) + '</span>' : '') + '</p>';
    }
    out += '<p class="muted">' + esc(v.kind) + (v.ship ? ' &middot; ' + esc(v.ship) : '') +
      (v.aliases && v.aliases.length ? ' &middot; also ' + v.aliases.map(esc).join(', ') : '') + '</p>';
    var attrs = Object.keys(v.attrs || {}).sort();
    out += '<div class="card"><h2>Now</h2>';
    if (!attrs.length) out += '<p class="muted">No current attributes.</p>';
    else {
      out += thead(['attribute', 'value', 'since', 'by', 'source']);
      attrs.forEach(function (a) {
        var rows = v.attrs[a];
        (Array.isArray(rows) ? rows : [rows]).forEach(function (r) {
          if (!r) return;
          out += '<tr>' + cell('attribute', esc(a)) + cell('value', fmtValue(r.value)) + cell('since', fmtTime(r.at)) +
            cell('by', esc(r.by || '')) + cell('source', source(r.source)) + '</tr>';
        });
      });
      out += '</tbody></table>';
    }
    out += '</div>';
    if (v.involved && v.involved.length) out += '<div class="card"><h2>Involved in</h2>' + situationCards(v.involved, state) + '</div>';
    if (v.actions && v.actions.length) {
      out += '<div class="card"><h2>Open actions</h2><ul class="actions">';
      v.actions.forEach(function (a) { out += '<li>' + badge(a.status) + ' ' + esc(a.title) + ' <span class="muted">' + esc(a.kind) + '</span></li>'; });
      out += '</ul></div>';
    }
    out += '<div class="card"><h2>Timeline</h2>';
    if (!v.observations || !v.observations.length) out += '<p class="muted">No observations.</p>';
    else {
      out += thead(['at', 'attribute', 'value', 'status', 'by', 'source', '']);
      v.observations.forEach(function (o) {
        out += '<tr class="' + esc(o.status) + '">' + cell('at', fmtTime(o.at)) + cell('attribute', esc(o.attr)) + cell('value', fmtValue(o.value)) +
          cell('status', badge(o.status) + (o.note ? ' <span class="muted">' + esc(o.note) + '</span>' : '')) +
          cell('by', esc(o.by || '')) + cell('source', source(o.source)) +
          cell('', o.status === 'live' ? '<button class="danger" data-retract="' + esc(o.id) + '">retract</button>' : '') + '</tr>';
      });
      out += '</tbody></table>';
    }
    out += '</div>';
    return out;
  }

  var MOVES = { proposed: ['approved', 'dismissed'], approved: ['done', 'failed', 'dismissed'], claimed: ['dismissed'] };
  // the claimant is the by of the last claimed step in the history
  function claimant(a) {
    var who = '';
    ((a && a.history) || []).forEach(function (h) { if (h && h.status === 'claimed') who = h.by || ''; });
    return who;
  }
  function inbox(actions, state) {
    var out = '<h1>Inbox</h1>';
    if (!actions || !actions.length) return out + '<p class="muted">Nothing waiting.</p>';
    var byId = index(state);
    out += '<ul class="actions">';
    actions.forEach(function (a) {
      out += '<li class="card">' + badge(a.status) +
        (a.status === 'claimed' ? ' <span class="muted">claimed by ' + esc(claimant(a)) + '</span>' : '') +
        ' <strong>' + esc(a.title) + '</strong> <span class="muted">' + esc(a.kind) +
        ' &middot; proposed ' + fmtTime(a.proposed) + ' by ' + esc(a.by || '') + (a.due ? ' &middot; due ' + fmtTime(a.due) : '') + '</span>' +
        (a.about && a.about.length ? '<div>about ' + links(a.about, byId) + '</div>' : '') + '<div>';
      (MOVES[a.status] || []).forEach(function (s) {
        out += '<button data-move="' + esc(a.id) + ':' + s + '"' + (s === 'dismissed' || s === 'failed' ? ' class="danger"' : '') + '>' + s + '</button>';
      });
      out += '</div></li>';
    });
    return out + '</ul>';
  }

  // the generator card: every setting but the key, which is written and
  // never read back; a run-now button; what the last pass did
  function generatorCard(g, last) {
    g = g || {}; last = last || {};
    var effort = g.reasoning && g.reasoning.enabled === false ? 'off' : (g.reasoning && g.reasoning.effort) || '';
    var out = '<div class="card"><h2>Generator</h2><div id="generator">' +
      '<p><label class="box"><input type="checkbox" name="enabled"' + (g.enabled ? ' checked' : '') + '> on: a pass runs when the state changes</label></p>' +
      '<p><label class="field">API base <input name="url" value="' + esc(g.url || '') + '" placeholder="https://openrouter.ai/api/v1"></label> ' +
      '<label class="field">model <input name="model" value="' + esc(g.model || '') + '" placeholder="moonshotai/kimi-k3"></label></p>' +
      '<p><label class="field">API key <input name="api_key" type="password" placeholder="' + (g.api_key_set ? 'a key is set; leave blank to keep it' : 'no key set') + '"></label> ' +
      '<label class="field">reasoning effort <input name="effort" value="' + esc(effort) + '" placeholder="high, medium, low, or off"></label></p>' +
      '<p><label class="field">max tokens <input name="max_tokens" value="' + esc(g.max_tokens || '') + '"></label> ' +
      '<label class="field">max actions <input name="max_actions" value="' + esc(g.max_actions || '') + '"></label></p>' +
      '<p><label class="field">minutes between model calls <input name="cooldown_minutes" value="' + esc(g.cooldown_minutes != null ? g.cooldown_minutes : '') + '"></label> ' +
      '<label class="field">calls per day at most <input name="max_daily" value="' + esc(g.max_daily != null ? g.max_daily : '') + '"></label></p>' +
      '<p><button data-save-generator="1">save generator</button><button data-generate="1">run a pass now</button></p></div>';
    if (last.at) {
      var u = last.usage || {};
      var calls = last.calls_today != null ? ' Model calls today: ' + last.calls_today + '.' : '';
      out += '<p class="muted">Last pass ' + fmtTime(last.at) + ': ' + (last.skipped ? 'skipped' :
        (last.error ? 'failed: ' + esc(last.error) : (last.filed || 0) + ' filed, ' + (last.dropped || 0) + ' dropped' +
        (u.cost != null ? ', $' + Number(u.cost).toFixed(4) : '') + (last.seconds != null ? ', ' + last.seconds + ' s' : ''))) + calls + '</p>';
      (last.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    return out + '</div>';
  }
  function settings(schema, policy, generator, last) {
    return '<h1>Settings</h1>' + generatorCard(generator, last) +
      '<div class="card"><h2>schema.json</h2><textarea id="schema" aria-label="schema.json">' + esc(JSON.stringify(schema, null, 2)) + '</textarea>' +
      '<p><button data-save="schema">save schema</button></p></div>' +
      '<div class="card"><h2>policy.json</h2><textarea id="policy" aria-label="policy.json">' + esc(JSON.stringify(policy, null, 2)) + '</textarea>' +
      '<p><button data-save="policy">save policy</button></p></div>';
  }

  // a key's scope in words: what it sees, what it may propose, whether it
  // writes, and whether it may file the sensitive attributes it never reads
  function scopeText(sc) {
    sc = sc || {};
    var parts = [sc.kinds && sc.kinds.length ? sc.kinds.join(', ') : 'no kinds',
      sc.actions && sc.actions.length ? 'actions ' + sc.actions.join(', ') : 'no actions',
      sc.write ? 'writes' : 'read-only'];
    if (sc.sensitive === 'write') parts.push('writes sensitive');
    return parts.join(' \u00b7 ');
  }
  // the keys: each with its identity, scope, when it was made and last
  // used (the ship records use to the hour), and a revoke; a mint form
  // built from the schema's kinds and action kinds; a token just minted
  // shown once, until dismissed or the view is left, and never again
  function keys(clients, schema, minted) {
    var out = '<h1>Keys</h1>';
    if (minted) {
      out += '<div class="card token"><h2>New key</h2><p>' + esc(minted.name || '') + ' <span class="muted">' + esc(minted.id || '') +
        ' \u00b7 writes as ' + esc(minted.by || '') + '</span></p>' +
        '<p>Its token, shown once. The ship keeps only a hash: put it in the client now.</p>' +
        '<p><code id="token">' + esc(minted.token || '') + '</code></p>' +
        '<p><button data-copy="token">copy</button><button data-dismiss-token="1">dismiss</button></p></div>';
    }
    out += '<div class="card"><h2>Minted keys</h2>';
    if (!clients || !clients.length) out += '<p class="muted">No keys yet.</p>';
    else {
      var rows = clients.slice().sort(function (a, b) { return (a.made || '') < (b.made || '') ? 1 : -1; });
      out += thead(['name', 'writes as', 'scope', 'made', 'last used', '']);
      rows.forEach(function (c) {
        out += '<tr>' + cell('name', esc(c.name || '') + '<span class="id">' + esc(c.id || '') + '</span>') + cell('writes as', esc(c.by || '')) +
          cell('scope', esc(scopeText(c.scope))) + cell('made', fmtTime(c.made)) +
          cell('last used', c.used ? fmtTime(c.used) : '<span class="muted">never</span>') +
          cell('', '<button class="danger" data-revoke="' + esc(c.id || '') + '" data-name="' + esc(c.name || c.id || '') + '">revoke</button>') + '</tr>';
      });
      out += '</tbody></table><p class="muted">Use is recorded to the hour. A revoked key is refused within a second.</p>';
    }
    out += '</div>';
    var kinds = Object.keys((schema && schema.kinds) || {}).sort();
    var actions = schema && Array.isArray(schema.actions) && schema.actions.length ? schema.actions : ['task', 'note', 'message', 'home', 'calendar'];
    function boxes(name, list, on) {
      return list.map(function (k) {
        return '<label class="box"><input type="checkbox" name="' + name + '" value="' + esc(k) + '"' + (on ? ' checked' : '') + '> ' + esc(k) + '</label>';
      }).join(' ');
    }
    out += '<div class="card"><h2>Mint a key</h2><div id="mint">' +
      '<p><label class="field">name <input name="name" maxlength="200" placeholder="Talon on the phone"></label> ' +
      '<label class="field">writes as <input name="by" maxlength="64" placeholder="talon"></label></p>' +
      '<p><span class="muted">sees</span> ' + boxes('kinds', kinds, true) + '</p>' +
      '<p><span class="muted">may propose</span> ' + boxes('actions', actions, false) + '</p>' +
      '<p><label class="box"><input type="checkbox" name="write"> may write</label> ' +
      '<label class="box wide"><input type="checkbox" name="sensitive"> may file the sensitive attributes it never reads (needs write)</label></p>' +
      '<p><button data-mint="1">mint</button></p></div></div>';
    return out;
  }

  function seg(id) { return String(id).split('/').map(encodeURIComponent).join('/'); }
  function route(hash) {
    var h = String(hash || '').replace(/^#/, '') || 'bodies';
    if (h.indexOf('body/') === 0) return { name: 'body', id: h.slice(5) };
    return { name: h };
  }
  // one block of the raw beacon stream: only its "event:" and "data:"
  // lines carry anything
  function sseEvent(block) {
    var name = '', data = '';
    String(block).split('\n').forEach(function (ln) {
      if (ln.indexOf('event: ') === 0) name = ln.slice(7).trim();
      else if (ln.indexOf('data: ') === 0) data = ln.slice(6).trim();
    });
    return { name: name, data: data };
  }

  var render = {
    phase: phase,
    bodies: bodies, body: body, inbox: inbox, settings: settings, keys: keys, esc: esc, fmtValue: fmtValue,
    seg: seg, route: route, sseEvent: sseEvent,
  };
  if (typeof module !== 'undefined' && module.exports) { module.exports = render; }
  if (typeof document === 'undefined') { return; }

  // ---- the app ----
  var view = document.getElementById('view');
  var statusEl = document.getElementById('status');
  var countEl = document.getElementById('inbox-count');
  var lastRev = null;
  var minted = null;

  function say(msg, bad) { statusEl.textContent = msg; statusEl.className = 'status' + (bad ? ' bad' : ''); }
  function api(path, opts) {
    return fetch(API + path, opts).then(function (r) {
      if (!r.ok) {
        return r.json().catch(function () { return {}; }).then(function (d) {
          throw new Error(d.error || ('http ' + r.status));
        });
      }
      return r.json();
    });
  }
  function post(path, bodyObj, method) {
    return api(path, { method: method || 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(bodyObj) });
  }

  var refreshing = false, again = false;
  function refresh() {
    if (refreshing) { again = true; return; }
    refreshing = true;
    var r = route(location.hash);
    var p;
    if (r.name !== 'keys') minted = null;
    function state() { return api('/state').then(function (s) { if (typeof s.rev === 'number') lastRev = String(s.rev); return s; }); }
    if (r.name === 'body') p = Promise.all([api('/body/' + seg(r.id)), state()]).then(function (d) { view.innerHTML = body(d[0], d[1]); });
    else if (r.name === 'inbox') p = Promise.all([api('/actions?status=open'), state()]).then(function (d) { view.innerHTML = inbox(d[0], d[1]); });
    else if (r.name === 'settings') p = Promise.all([api('/schema'), api('/policy'), api('/generator'), api('/generator/last')]).then(function (d) { view.innerHTML = settings(d[0], d[1], d[2], d[3]); });
    else if (r.name === 'keys') p = Promise.all([api('/clients'), api('/schema')]).then(function (d) { view.innerHTML = keys(d[0], d[1], minted); });
    else p = state().then(function (s) { view.innerHTML = bodies(s); });
    p = p.then(function () { return api('/actions?status=proposed'); }).then(function (a) {
      countEl.textContent = a.length ? String(a.length) : '';
      say('');
    }).catch(function (e) { say(String(e.message || e), true); });
    p.then(function () { refreshing = false; if (again) { again = false; refresh(); } });
  }

  // a write answers before the writer applies, so the refetch waits
  function later() { setTimeout(refresh, 300); }

  view.addEventListener('click', function (ev) {
    var b = ev.target.closest('button');
    if (!b) return;
    if (b.dataset.retract) {
      var note = prompt('Why retract this observation?');
      if (note === null) return;
      post('/retract', { id: b.dataset.retract, note: note, by: 'page' }).then(later).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.move) {
      var cut = b.dataset.move.indexOf(':');
      var moveId = b.dataset.move.slice(0, cut), moveTo = b.dataset.move.slice(cut + 1);
      var move = { status: moveTo, by: 'page' };
      if (moveTo === 'dismissed') {
        // the reason rides in the note and reaches the generator's prompt
        // with the decision, where it teaches taste, not just this title
        var why = prompt('Why? Optional, but it teaches the generator: "just the event", "I always do this", "not mine to do".');
        if (why === null) return;
        if (why.trim()) move.note = why.trim().slice(0, 500);
      }
      post('/actions/' + seg(moveId), move).then(later).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.save) {
      var which = b.dataset.save;
      var parsed;
      try { parsed = JSON.parse(document.getElementById(which).value); } catch (e) { say(which + ': ' + e.message, true); return; }
      post('/' + which, parsed, 'PUT').then(function () { say(which + ' saved'); }).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.revoke) {
      if (!confirm('Revoke "' + b.dataset.name + '"? Its next request is refused.')) return;
      api('/clients/' + seg(b.dataset.revoke), { method: 'DELETE' }).then(later).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.mint) {
      post('/clients', mintForm()).then(function (d) { minted = d; refresh(); }).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.copy) {
      var text = document.getElementById(b.dataset.copy).textContent;
      if (!navigator.clipboard) { say('copy by hand: the browser offers no clipboard here', true); return; }
      navigator.clipboard.writeText(text).then(function () { say('copied'); }, function () { say('copy failed: select it by hand', true); });
    } else if (b.dataset.dismissToken) {
      minted = null;
      refresh();
    } else if (b.dataset.saveGenerator) {
      post('/generator', generatorForm(), 'PUT').then(function () { say('generator saved'); later(); }).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.generate) {
      post('/generate', {}).then(function () { say('pass started; the last pass line updates when it ends'); setTimeout(refresh, 30000); }).catch(function (e) { say(e.message, true); });
    }
  });
  // the generator form as the API takes it; a blank key is left out so
  // the stored one stays; "off" reasoning is {"enabled": false}
  function generatorForm() {
    function val(name) { var el = view.querySelector('#generator input[name="' + name + '"]'); return el ? el.value.trim() : ''; }
    var effort = val('effort').toLowerCase();
    var g = { enabled: !!view.querySelector('#generator input[name="enabled"]:checked'), url: val('url'), model: val('model'),
      reasoning: effort === 'off' ? { enabled: false } : { effort: effort || 'high' },
      max_tokens: parseInt(val('max_tokens'), 10) || 8000, max_actions: parseInt(val('max_actions'), 10) || 5,
      cooldown_minutes: parseInt(val('cooldown_minutes'), 10) || 0, max_daily: parseInt(val('max_daily'), 10) || 0 };
    if (val('api_key')) g.api_key = val('api_key');
    return g;
  }
  // the mint form as the API takes it; sensitive: write only rides with write
  function mintForm() {
    function val(name) { var el = view.querySelector('#mint input[name="' + name + '"]'); return el ? el.value.trim() : ''; }
    function picked(name) {
      return Array.prototype.map.call(view.querySelectorAll('#mint input[name="' + name + '"]:checked'), function (el) { return el.value; });
    }
    var write = picked('write').length > 0;
    return { name: val('name'), by: val('by'),
      scope: { kinds: picked('kinds'), actions: picked('actions'), write: write, sensitive: write && picked('sensitive').length ? 'write' : 'none' } };
  }
  window.addEventListener('hashchange', refresh);
  document.addEventListener('visibilitychange', function () { if (!document.hidden) refresh(); });

  // ---- the beacon stream, read raw (the initial event is named "old
  // /rev", which EventSource cannot subscribe to; it carries the current
  // rev, so a bump missed while nobody watched shows as a difference) ----
  var timer = null;
  // a re-render replaces the settings textareas and the mint form, so a
  // bump waits while one of them has focus; the next bump after blur
  // refreshes
  function editing() {
    var el = document.activeElement;
    return !!(el && (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT') && view.contains(el));
  }
  function bumped() {
    if (editing()) return;
    clearTimeout(timer);
    timer = setTimeout(function () { if (!editing()) refresh(); }, 300);
  }
  async function stream() {
    for (;;) {
      if (document.hidden) { await new Promise(function (r) { setTimeout(r, 1000); }); continue; }
      try {
        var resp = await fetch(KEEP, { headers: { Accept: 'text/event-stream' } });
        if (!resp.ok) {
          say('live updates off', true);
          await new Promise(function (r) { setTimeout(r, 30000); });
          continue;
        }
        var rd = resp.body.getReader();
        var dec = new TextDecoder();
        var buf = '';
        for (;;) {
          var chunk = await rd.read();
          if (chunk.done) break;
          buf += dec.decode(chunk.value, { stream: true });
          var evs = buf.split('\n\n');
          buf = evs.pop();
          evs.forEach(function (ev) {
            if (document.hidden) return;
            var parsed = sseEvent(ev);
            var name = parsed.name, data = parsed.data;
            if (!name || name.slice(-4) !== '/rev') return;
            if (name.indexOf('old') === 0) { if (lastRev !== null && data && data !== lastRev) bumped(); lastRev = data; return; }
            lastRev = data;
            bumped();
          });
        }
      } catch (e) { /* the stream severed: reconnect below */ }
      await new Promise(function (r) { setTimeout(r, 3000); });
    }
  }
  refresh();
  stream();
  setInterval(function () { if (!document.hidden) refresh(); }, 60000);
})();
