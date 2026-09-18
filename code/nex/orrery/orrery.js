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
      out += '<table><tr><th scope="col">attribute</th><th scope="col">value</th><th scope="col">since</th>' +
        '<th scope="col">by</th><th scope="col">source</th></tr>';
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
    if (v.involved && v.involved.length) out += '<div class="card"><h2>Involved in</h2>' + situationCards(v.involved, state) + '</div>';
    if (v.actions && v.actions.length) {
      out += '<div class="card"><h2>Open actions</h2><ul class="actions">';
      v.actions.forEach(function (a) { out += '<li>' + badge(a.status) + ' ' + esc(a.title) + ' <span class="muted">' + esc(a.kind) + '</span></li>'; });
      out += '</ul></div>';
    }
    out += '<div class="card"><h2>Timeline</h2>';
    if (!v.observations || !v.observations.length) out += '<p class="muted">No observations.</p>';
    else {
      out += '<table><tr><th scope="col">at</th><th scope="col">attribute</th><th scope="col">value</th>' +
        '<th scope="col">status</th><th scope="col">by</th><th scope="col">source</th><th scope="col"></th></tr>';
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

  function settings(schema, policy) {
    return '<h1>Settings</h1>' +
      '<div class="card"><h2>schema.json</h2><textarea id="schema" aria-label="schema.json">' + esc(JSON.stringify(schema, null, 2)) + '</textarea>' +
      '<p><button data-save="schema">save schema</button></p></div>' +
      '<div class="card"><h2>policy.json</h2><textarea id="policy" aria-label="policy.json">' + esc(JSON.stringify(policy, null, 2)) + '</textarea>' +
      '<p><button data-save="policy">save policy</button></p></div>';
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
    bodies: bodies, body: body, inbox: inbox, settings: settings, esc: esc, fmtValue: fmtValue,
    seg: seg, route: route, sseEvent: sseEvent,
  };
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
  function post(path, bodyObj, method) {
    return api(path, { method: method || 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(bodyObj) });
  }

  var refreshing = false, again = false;
  function refresh() {
    if (refreshing) { again = true; return; }
    refreshing = true;
    var r = route(location.hash);
    var p;
    function state() { return api('/state').then(function (s) { if (typeof s.rev === 'number') lastRev = String(s.rev); return s; }); }
    if (r.name === 'body') p = Promise.all([api('/body/' + seg(r.id)), state()]).then(function (d) { view.innerHTML = body(d[0], d[1]); });
    else if (r.name === 'inbox') p = Promise.all([api('/actions?status=open'), state()]).then(function (d) { view.innerHTML = inbox(d[0], d[1]); });
    else if (r.name === 'settings') p = Promise.all([api('/schema'), api('/policy')]).then(function (d) { view.innerHTML = settings(d[0], d[1]); });
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
      post('/actions/' + seg(moveId), { status: moveTo, by: 'page' }).then(later).catch(function (e) { say(e.message, true); });
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
  // a re-render replaces the settings textareas, so a bump waits while
  // one of them has focus; the next bump after blur refreshes
  function editing() {
    var el = document.activeElement;
    return !!(el && el.tagName === 'TEXTAREA' && view.contains(el));
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
