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
  function links(ids) { return (ids || []).map(function (b) { return '<a href="#body/' + esc(b) + '">' + esc(b) + '</a>'; }).join(', '); }
  function badge(s) { return '<span class="badge ' + esc(s) + '">' + esc(s) + '</span>'; }

  function bodies(state) {
    var byKind = Object.create(null);
    (state.bodies || []).forEach(function (b) { (byKind[b.kind] = byKind[b.kind] || []).push(b); });
    var kinds = Object.keys(byKind).sort();
    var out = '<h1>Bodies</h1>';
    if (state.situations && state.situations.length) {
      out += '<div class="card"><strong>Open situations:</strong> ' + links(state.situations) + '</div>';
    }
    kinds.forEach(function (k) {
      out += '<h2>' + esc(k) + '</h2><div class="bodies">';
      byKind[k].sort(function (a, b) { return a.id < b.id ? -1 : 1; }).forEach(function (b) {
        var n = Object.keys(b.attrs || {}).length;
        out += '<a href="#body/' + esc(b.id) + '">' + esc(b.name || b.id) +
          (b.ship ? ' <span class="muted">' + esc(b.ship) + '</span>' : '') +
          '<span class="id">' + esc(b.id) + (n ? ' &middot; ' + n + ' attr' + (n === 1 ? '' : 's') : '') + '</span></a>';
      });
      out += '</div>';
    });
    if (!kinds.length) out += '<p class="muted">Nothing observed yet.</p>';
    return out;
  }

  function body(v) {
    var out = '<h1>' + esc(v.name || v.id) + ' <span class="muted">' + esc(v.id) + '</span></h1>';
    out += '<p class="muted">' + esc(v.kind) + (v.ship ? ' &middot; ' + esc(v.ship) : '') +
      (v.aliases && v.aliases.length ? ' &middot; also ' + v.aliases.map(esc).join(', ') : '') + '</p>';
    var attrs = Object.keys(v.attrs || {}).sort();
    out += '<div class="card"><h2>Now</h2>';
    if (!attrs.length) out += '<p class="muted">No current attributes.</p>';
    else {
      out += '<table><tr><th>attribute</th><th>value</th><th>since</th><th>by</th><th>source</th></tr>';
      attrs.forEach(function (a) {
        var rows = v.attrs[a];
        (Array.isArray(rows) ? rows : [rows]).forEach(function (r) {
          if (!r) return;
          out += '<tr><td>' + esc(a) + '</td><td>' + fmtValue(r.value) + '</td><td>' + fmtTime(r.at) +
            '</td><td>' + esc(r.by || '') + '</td><td>' + source(r.source) + '</td></tr>';
        });
      });
      out += '</table>';
    }
    out += '</div>';
    if (v.involved && v.involved.length) out += '<div class="card"><h2>Involved in</h2>' + links(v.involved) + '</div>';
    if (v.actions && v.actions.length) {
      out += '<div class="card"><h2>Open actions</h2><ul class="actions">';
      v.actions.forEach(function (a) { out += '<li>' + badge(a.status) + ' ' + esc(a.title) + ' <span class="muted">' + esc(a.kind) + '</span></li>'; });
      out += '</ul></div>';
    }
    out += '<div class="card"><h2>Timeline</h2>';
    if (!v.observations || !v.observations.length) out += '<p class="muted">No observations.</p>';
    else {
      out += '<table><tr><th>at</th><th>attribute</th><th>value</th><th>status</th><th>by</th><th>source</th><th></th></tr>';
      v.observations.forEach(function (o) {
        out += '<tr class="' + esc(o.status) + '"><td>' + fmtTime(o.at) + '</td><td>' + esc(o.attr) + '</td><td>' + fmtValue(o.value) +
          '</td><td>' + badge(o.status) + (o.note ? ' <span class="muted">' + esc(o.note) + '</span>' : '') +
          '</td><td>' + esc(o.by || '') + '</td><td>' + source(o.source) + '</td><td>' +
          (o.status === 'live' ? '<button class="danger" data-retract="' + esc(o.id) + '">retract</button>' : '') + '</td></tr>';
      });
      out += '</table>';
    }
    out += '</div>';
    return out;
  }

  var MOVES = { proposed: ['approved', 'dismissed'], approved: ['done', 'failed', 'dismissed'] };
  function inbox(actions) {
    var out = '<h1>Inbox</h1>';
    if (!actions || !actions.length) return out + '<p class="muted">Nothing waiting.</p>';
    out += '<ul class="actions">';
    actions.forEach(function (a) {
      out += '<li class="card">' + badge(a.status) + ' <strong>' + esc(a.title) + '</strong> <span class="muted">' + esc(a.kind) +
        ' &middot; proposed ' + fmtTime(a.proposed) + ' by ' + esc(a.by || '') + (a.due ? ' &middot; due ' + fmtTime(a.due) : '') + '</span>' +
        (a.about && a.about.length ? '<div>about ' + links(a.about) + '</div>' : '') + '<div>';
      (MOVES[a.status] || []).forEach(function (s) {
        out += '<button data-move="' + esc(a.id) + ':' + s + '"' + (s === 'dismissed' || s === 'failed' ? ' class="danger"' : '') + '>' + s + '</button>';
      });
      out += '</div></li>';
    });
    return out + '</ul>';
  }

  function settings(schema, policy) {
    return '<h1>Settings</h1>' +
      '<div class="card"><h2>schema.json</h2><textarea id="schema">' + esc(JSON.stringify(schema, null, 2)) + '</textarea>' +
      '<p><button data-save="schema">save schema</button></p></div>' +
      '<div class="card"><h2>policy.json</h2><textarea id="policy">' + esc(JSON.stringify(policy, null, 2)) + '</textarea>' +
      '<p><button data-save="policy">save policy</button></p></div>';
  }

  var render = { bodies: bodies, body: body, inbox: inbox, settings: settings, esc: esc, fmtValue: fmtValue };
  if (typeof module !== 'undefined' && module.exports) { module.exports = render; }
  if (typeof document === 'undefined') { return; }

  // ---- the app ----
  var view = document.getElementById('view');
  var statusEl = document.getElementById('status');
  var countEl = document.getElementById('inbox-count');
  var lastRev = null;

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
  function seg(id) { return String(id).split('/').map(encodeURIComponent).join('/'); }
  function post(path, bodyObj, method) {
    return api(path, { method: method || 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(bodyObj) });
  }

  function route() {
    var h = location.hash.replace(/^#/, '') || 'bodies';
    if (h.indexOf('body/') === 0) return { name: 'body', id: h.slice(5) };
    return { name: h };
  }
  var refreshing = false, again = false;
  function refresh() {
    if (refreshing) { again = true; return; }
    refreshing = true;
    var r = route();
    var p;
    if (r.name === 'body') p = api('/body/' + seg(r.id)).then(function (v) { view.innerHTML = body(v); });
    else if (r.name === 'inbox') p = api('/actions?status=open').then(function (a) { view.innerHTML = inbox(a); });
    else if (r.name === 'settings') p = Promise.all([api('/schema'), api('/policy')]).then(function (d) { view.innerHTML = settings(d[0], d[1]); });
    else p = api('/state').then(function (s) { view.innerHTML = bodies(s); if (typeof s.rev === 'number') lastRev = String(s.rev); });
    p = p.then(function () { return api('/actions?status=proposed'); }).then(function (a) {
      countEl.textContent = a.length ? String(a.length) : '';
      say('');
    }).catch(function (e) { say(String(e.message || e), true); });
    p.then(function () { refreshing = false; if (again) { again = false; refresh(); } });
  }

  view.addEventListener('click', function (ev) {
    var b = ev.target.closest('button');
    if (!b) return;
    if (b.dataset.retract) {
      var note = prompt('Why retract this observation?') ;
      if (note === null) return;
      post('/retract', { id: b.dataset.retract, note: note }).then(refresh).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.move) {
      var cut = b.dataset.move.indexOf(':');
      var moveId = b.dataset.move.slice(0, cut), moveTo = b.dataset.move.slice(cut + 1);
      post('/actions/' + seg(moveId), { status: moveTo, by: 'page' }).then(refresh).catch(function (e) { say(e.message, true); });
    } else if (b.dataset.save) {
      var which = b.dataset.save;
      var parsed;
      try { parsed = JSON.parse(document.getElementById(which).value); } catch (e) { say(which + ': ' + e.message, true); return; }
      post('/' + which, parsed, 'PUT').then(function () { say(which + ' saved'); }).catch(function (e) { say(e.message, true); });
    }
  });
  window.addEventListener('hashchange', refresh);
  document.addEventListener('visibilitychange', function () { if (!document.hidden) refresh(); });

  // ---- the beacon stream, read raw (the initial event is named "old
  // /rev", which EventSource cannot subscribe to; it carries the current
  // rev, so a bump missed while nobody watched shows as a difference) ----
  var timer = null;
  function bumped() { clearTimeout(timer); timer = setTimeout(refresh, 300); }
  async function stream() {
    for (;;) {
      if (document.hidden) { await new Promise(function (r) { setTimeout(r, 1000); }); continue; }
      try {
        var resp = await fetch(KEEP, { headers: { Accept: 'text/event-stream' } });
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
            var name = '', data = '';
            ev.split('\n').forEach(function (ln) {
              if (ln.indexOf('event: ') === 0) name = ln.slice(7).trim();
              else if (ln.indexOf('data: ') === 0) data = ln.slice(6).trim();
            });
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
