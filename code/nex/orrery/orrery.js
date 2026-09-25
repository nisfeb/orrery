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
  // a stamp as the reader's own clock shows it, in local time; the ship
  // speaks UTC and a stamp it cannot parse is shown as it came
  function fmtTime(t) {
    if (!t) return '';
    var d = new Date(String(t));
    if (isNaN(d.getTime())) return esc(String(t).replace('T', ' ').replace('Z', ''));
    function two(n) { return (n < 10 ? '0' : '') + n; }
    return d.getFullYear() + '-' + two(d.getMonth() + 1) + '-' + two(d.getDate()) + ' ' + two(d.getHours()) + ':' + two(d.getMinutes()) + ':' + two(d.getSeconds());
  }
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

  // the bodies view (version 58): every body a node, every ref
  // attribute an edge, laid out in three dimensions and drawn on a
  // canvas; a click picks a node or an edge and the pane beside it
  // says what the ship knows. The list a hundred bodies made was not
  // something to read; the shape of the connections is.
  var KIND_COLORS = { person: '#f9a804', place: '#3b82f6', thing: '#10b981', org: '#8b5cf6', situation: '#ef4444', activity: '#f97316', note: '#6b7280' };
  function graphOf(state, showPast) {
    var nodes = [], byId = Object.create(null), edges = [], seen = Object.create(null);
    (state.bodies || []).forEach(function (b) {
      var st = b.attrs && b.attrs.status, closed = !!(st && !Array.isArray(st) && (st.value === 'closed' || st.value === 'cancelled'));
      if (b.kind === 'situation' && closed && !showPast) return;
      var n = { id: b.id, kind: b.kind, name: b.name || b.id, body: b, closed: closed, degree: 0 };
      nodes.push(n); byId[b.id] = n;
    });
    function edge(from, to, attr, at) {
      if (!byId[from] || !byId[to] || from === to) return;
      var key = from < to ? from + '|' + to + '|' + attr : to + '|' + from + '|' + attr;
      if (seen[key]) return;
      seen[key] = true;
      edges.push({ from: from, to: to, attr: attr, at: at });
      byId[from].degree += 1; byId[to].degree += 1;
    }
    nodes.forEach(function (n) {
      Object.keys(n.body.attrs || {}).forEach(function (a) {
        var rows = n.body.attrs[a];
        (Array.isArray(rows) ? rows : [rows]).forEach(function (r) {
          if (r && r.value && typeof r.value === 'object' && r.value.ref) edge(n.id, r.value.ref, a, r.at);
        });
      });
      (n.body.involved || []).forEach(function (sid) { edge(n.id, sid, 'involved', ''); });
    });
    return { nodes: nodes, edges: edges, byId: byId };
  }
  function bodies(state) {
    var n = (state.bodies || []).length;
    var out = '<h1>Bodies <span class="muted">' + n + '</span></h1>' +
      '<div class="graph-bar"><input id="graph-find" placeholder="find a body by name" aria-label="find a body">' +
      '<label class="box"><input type="checkbox" id="graph-past"> past situations</label>' +
      '<span class="muted">drag to turn, wheel to zoom, click a body or a line</span></div>' +
      '<div class="graph"><canvas id="graph" aria-label="the bodies and their connections"></canvas>' +
      '<aside id="graph-pane" class="card"><p class="muted">Nothing picked. Click a body or a line between two.</p>' +
      '<ul class="legend">' + Object.keys(KIND_COLORS).map(function (k) { return '<li><i style="background:' + KIND_COLORS[k] + '"></i>' + esc(k) + '</li>'; }).join('') + '</ul></aside></div>';
    if (!n) out += '<p class="muted">Nothing observed yet.</p>';
    return out;
  }
  // what the pane says of a node: the body's current attributes and its
  // connections, each a link that picks the other end
  function nodePane(n, g) {
    var out = '<h2>' + esc(n.kind) + '</h2><p><strong>' + esc(n.name) + '</strong> <a class="muted" href="#body/' + esc(n.id) + '">' + esc(n.id) + ' &rarr;</a></p>';
    var attrs = Object.keys(n.body.attrs || {}).sort();
    if (attrs.length) {
      out += '<table><tbody>';
      attrs.forEach(function (a) {
        var rows = n.body.attrs[a];
        (Array.isArray(rows) ? rows : [rows]).forEach(function (r) { if (r) out += '<tr><th>' + esc(a) + '</th><td>' + fmtValue(r.value) + '</td></tr>'; });
      });
      out += '</tbody></table>';
    }
    var links = g.edges.filter(function (e) { return e.from === n.id || e.to === n.id; });
    if (links.length) {
      out += '<h3>Connections</h3><ul class="links">';
      links.forEach(function (e) {
        var other = e.from === n.id ? e.to : e.from, o = g.byId[other];
        out += '<li><span class="muted">' + esc(e.attr) + '</span> <a href="#" data-pick="' + esc(other) + '">' + esc(o ? o.name : other) + '</a></li>';
      });
      out += '</ul>';
    }
    return out;
  }
  function edgePane(e, g) {
    var a = g.byId[e.from], b = g.byId[e.to];
    return '<h2>connection</h2><p><a href="#" data-pick="' + esc(e.from) + '">' + esc(a ? a.name : e.from) + '</a> <span class="muted">' + esc(e.attr) + '</span> <a href="#" data-pick="' + esc(e.to) + '">' + esc(b ? b.name : e.to) + '</a></p>' +
      (e.at ? '<p class="muted">since ' + fmtTime(e.at) + '</p>' : '');
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
  var REFINABLE = ['task', 'calendar', 'message'];
  // the claimant is the by of the last claimed step in the history
  function claimant(a) {
    var who = '';
    ((a && a.history) || []).forEach(function (h) { if (h && h.status === 'claimed') who = h.by || ''; });
    return who;
  }
  // what an action will do, shown before it is approved: the recipient,
  // the text, the channel, a calendar event's times or that it is a
  // cancel. A title says what the proposer meant; the payload is what
  // the executor sends.
  function payloadLine(p, byId) {
    var keys = Object.keys(p || {}).filter(function (k) { return k !== 'why'; }).sort();
    if (!keys.length) return '';
    return '<div class="payload">' + keys.map(function (k) {
      var v = p[k];
      var shown = (k === 'to' && typeof v === 'string' && v.indexOf('/') > 0) ? links([v], byId) : fmtValue(v);
      return '<span class="muted">' + esc(k) + '</span> ' + shown;
    }).join(' &middot; ') + '</div>';
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
        (a.about && a.about.length ? '<div>about ' + links(a.about, byId) + '</div>' : '') + payloadLine(a.payload, byId) + '<div>';
      (MOVES[a.status] || []).forEach(function (s) {
        out += '<button data-move="' + esc(a.id) + ':' + s + '"' + (s === 'dismissed' || s === 'failed' ? ' class="danger"' : '') + '>' + s + '</button>';
      });
      out += '</div>';
      // A note under a proposed action refines it before approval (version 36).
      // The ship refines the reader's three kinds and no other, since a merge
      // or a home action has no payload shape a note could be held to; the
      // three are the lib's reader-kinds, fixed there, so they are fixed here.
      if (a.status === 'proposed' && REFINABLE.indexOf(a.kind) >= 0) {
        out += '<p class="refine"><input data-refine-text="' + esc(a.id) + '" placeholder="a note for this action"> <button data-refine="' + esc(a.id) + '">refine</button> <span class="muted" data-refine-note="' + esc(a.id) + '"></span></p>';
      }
      out += '</li>';
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
      '<label class="field">calls per day at most <input name="max_daily" value="' + esc(g.max_daily != null ? g.max_daily : '') + '"></label> ' +
      '<label class="field">urgent passes per day <input name="max_urgent" value="' + esc(g.max_urgent != null ? g.max_urgent : '') + '"></label></p>' +
      '<p><button data-save-generator="1">save generator</button><button data-generate="1">run a pass now</button></p></div>';
    if (last.at) {
      var u = last.usage || {};
      var calls = last.calls_today != null ? ' Model calls today: ' + last.calls_today + (last.urgent_today ? ' (' + last.urgent_today + ' urgent)' : '') + '.' : '';
      if (last.spend_month_micro != null) calls += ' This month: $' + (last.spend_month_micro / 1e6).toFixed(2) + '.';
      out += '<p class="muted">Last pass ' + fmtTime(last.at) + ': ' + (last.skipped ? 'skipped' :
        (last.error ? 'failed: ' + esc(last.error) : (last.filed || 0) + ' filed, ' + (last.dropped || 0) + ' dropped' +
        (u.cost != null ? ', $' + Number(u.cost).toFixed(4) : '') + (last.seconds != null ? ', ' + last.seconds + ' s' : ''))) + calls + '</p>';
      (last.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    return out + '</div>';
  }
  // the reconcile card: what the last run of the on-ship passes did, and
  // a run-now button; the settings themselves live in policy.reconcile
  function reconcileCard(last) {
    last = last || {};
    var out = '<div class="card"><h2>Reconcile</h2><p class="muted">Twice a day the ship turns repeated situations into activities, ' +
      'reads people out of titles, proposes merges of bodies that name one person, runs the merges you approved, ' +
      'moves future facts to the schedule and closes what is over. Settings: <code>reconcile</code> in policy.json ' +
      '(min_occurrences, stale_days, prune_days).</p><p><button data-reconcile="1">run now</button></p>';
    if (last.at) {
      var acts = last.activities || [];
      out += '<p class="muted">Last run ' + fmtTime(last.at) + ': ' + (last.times || 0) + ' time rows fixed, ' +
        acts.length + ' activit' + (acts.length === 1 ? 'y' : 'ies') + (acts.length ? ' (' + esc(acts.join(', ')) + ')' : '') + ', ' +
        (last.people_made || 0) + ' people made, ' + (last.participants || 0) + ' participants added, ' +
        (last.proposed || 0) + ' merges proposed, ' + (last.merged || 0) + ' merged, ' +
        (last.retired || 0) + ' retired, ' + (last.pruned || 0) + ' pruned.</p>';
    }
    return out + '</div>';
  }
  // the executor card: what the ship's last pass did (messages sent,
  // events and todos placed, the todo list kept in step), the failures
  // with their notes, the desks link could not find, and a wake button;
  // there are no settings, since the executor uses the reader's token and
  // the desks the owner consented to on the permits page
  function executorCard(last, cal) {
    last = last || {}; cal = cal || {};
    var out = '<div class="card"><h2>Executor</h2><p class="muted">The ship carries out approved actions itself: a message via telegram through the bot, ' +
      'via mail through auspex to the person\'s ship, a calendar action onto the calendar, a task into its todo list; and it keeps the todo list and the tasks ' +
      'in step both ways. A message via chat is left for the client that sends chat.</p><p><button data-exec-wake="1">wake the executor</button></p>';
    if (last.at) {
      out += '<p class="muted">Last looked ' + fmtTime(last.at) + '.' + (last.acted_at ? ' Last acted ' + fmtTime(last.acted_at) + ': ' +
        (last.claimed || 0) + ' claimed, ' + (last.sent || 0) + ' sent, ' + (last.placed || 0) + ' placed, ' +
        (last.ticked || 0) + ' todos ticked, ' + (last.deleted || 0) + ' deleted, ' + (last.moved || 0) + ' moved, ' +
        (last.closed || 0) + ' tasks closed from the calendar, ' + (last.adopted || 0) + ' todos adopted.' : ' Nothing done yet.') + '</p>';
      (last.failed || []).forEach(function (f) { out += '<p class="bad">failed: ' + esc(f.title || f.id || '') + ' <span class="muted">' + esc(f.note || '') + '</span></p>'; });
      (last.missing || []).forEach(function (d) { out += '<p class="bad">The ' + esc(d) + ' desk is not installed: what it would carry out stays approved for another executor.</p>'; });
      (last.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    if (cal.at) {
      out += '<p class="muted">Calendar events read ' + fmtTime(cal.at) + ': ' + (cal.events || 0) + ' on the calendar.' + (cal.acted_at ? ' Last written ' + fmtTime(cal.acted_at) + ': ' +
        (cal.made || 0) + ' bodies made, ' + (cal.rows || 0) + ' facts, ' + (cal.cancelled || 0) + ' cancelled.' : ' Nothing written yet.') + '</p>';
    }
    return out + '</div>';
  }
  // the telegram card: the reader's settings, the token and secret written
  // and never read back, the webhook registered from here, the last update
  function telegramCard(t, last) {
    t = t || {}; last = last || {};
    var people = t.people ? JSON.stringify(t.people, null, 2) : '{}';
    var out = '<div class="card"><h2>Telegram</h2><div id="telegram">' +
      '<p><label class="box"><input type="checkbox" name="enabled"' + (t.enabled ? ' checked' : '') + '> on: the ship reads the chats below through its webhook</label></p>' +
      '<p><label class="field">bot token <input name="token" type="password" placeholder="' + (t.token_set ? 'a token is set; leave blank to keep it' : 'no token set') + '"></label> ' +
      '<label class="field">webhook secret <input name="secret" type="password" placeholder="' + (t.secret_set ? 'a secret is set; leave blank to keep it' : 'no secret set') + '"></label>' +
      '<button data-make-secret="1" title="fill the secret with 32 random bytes; it is saved with the form">make one</button></p>' +
      '<p><label class="field">public URL of this ship <input name="public_url" value="' + esc(t.public_url || '') + '" placeholder="https://your.ship"></label> ' +
      '<label class="field">reader model <input name="model" value="' + esc(t.model || '') + '"></label></p>' +
      '<p><label class="field">chats (ids, comma separated) <input name="chats" value="' + esc((t.chats || []).join(',')) + '"></label></p>' +
      '<p><label class="field wide">people (Telegram user id to body id, JSON) <textarea name="people" rows="3">' + esc(people) + '</textarea></label></p>' +
      '<p><label class="field">gate (hundredths) <input name="gate" value="' + esc(t.gate != null ? t.gate : '') + '"></label> ' +
      '<label class="field">escalate (hundredths) <input name="escalate" value="' + esc(t.escalate != null ? t.escalate : '') + '"></label> ' +
      '<label class="field">messages per day at most <input name="max_daily_messages" value="' + esc(t.max_daily_messages != null ? t.max_daily_messages : '') + '"></label></p>' +
      '<p><button data-save-telegram="1">save telegram</button><button data-webhook="1">register the webhook</button><button data-webhook-info="1">what Telegram holds</button></p><p class="muted" id="webhook-info"></p></div>';
    if (last.at) {
      out += '<p class="muted">Last update ' + esc(String(last.update_id)) + ' at ' + fmtTime(last.at) + ' from ' + esc(last.from || '') + ' in ' + esc(last.chat || '') + ': ' + esc(last.outcome || '') + '. Read today: ' + (last.read_today || 0) + '.</p>';
      (last.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    if (last.down && last.down.update_id) {
      out += '<p class="bad">Update ' + esc(String(last.down.update_id)) + ' is waiting since ' + fmtTime(last.down.at) + ': the model could not be read. It retries every five minutes; fix the model or the key and press wake.</p>';
      (last.down.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
      out += '<p><button data-wake="1">wake the reader</button></p>';
    }
    return out + '</div>';
  }
  // the chat card: the Tlon reader's settings, the DMs and channels the
  // ship holds offered as boxes beside the lists, the people map, the last pass
  var chatLists = { dms: [], channels: [] };
  function labelOf(item) { return item.name ? esc(item.name) + ' <small class="muted">' + esc(item.id) + '</small>' : esc(item.id); }
  function pickedList(kind, ids) {
    var known = {};
    chatLists[kind].forEach(function (x) { known[x.id] = x; });
    if (!ids.length) return '<ul class="picked" data-picked="' + kind + '"><li class="muted" data-empty="1">none picked</li></ul>';
    return '<ul class="picked" data-picked="' + kind + '">' + ids.map(function (id) {
      return '<li data-id="' + esc(id) + '">' + labelOf(known[id] || { id: id }) + ' <button class="small" data-unpick="' + kind + '">remove</button></li>';
    }).join('') + '</ul>';
  }
  // the picker: a search box and the matches under it, filtered as the
  // owner types, by name or id; a click on one adds it to the list
  function picker(kind, what) {
    return '<p><label class="field wide">add a ' + what + ' <input name="' + kind + '-find" placeholder="type a name or id to filter" autocomplete="off"></label></p>' +
      '<ul class="matches" data-matches="' + kind + '"></ul>';
  }
  function matchesHtml(kind, q) {
    q = (q || '').trim().toLowerCase();
    var picked = {};
    Array.prototype.forEach.call(view.querySelectorAll('[data-picked="' + kind + '"] li[data-id]'), function (li) { picked[li.dataset.id] = true; });
    var hits = chatLists[kind].filter(function (x) { return !picked[x.id] && (!q || (x.name || '').toLowerCase().indexOf(q) >= 0 || x.id.toLowerCase().indexOf(q) >= 0); });
    if (!hits.length) return q ? '<li class="muted">nothing matches</li>' : '';
    return hits.slice(0, 30).map(function (x) { return '<li><button class="small" data-pick="' + kind + '" data-id="' + esc(x.id) + '">add</button> ' + labelOf(x) + '</li>'; }).join('') +
      (hits.length > 30 ? '<li class="muted">' + (hits.length - 30) + ' more; type to narrow</li>' : '');
  }
  function chatCard(c, last, dms, channels) {
    c = c || {}; last = last || {}; dms = dms || {}; channels = channels || {};
    chatLists = { dms: dms.items || [], channels: channels.items || [] };
    var people = c.people ? JSON.stringify(c.people, null, 2) : '{}';
    var out = '<div class="card"><h2>Chat</h2><div id="chat">' +
      '<p><label class="box"><input type="checkbox" name="enabled"' + (c.enabled ? ' checked' : '') + '> on: the ship reads the Tlon DMs and channels below every few minutes</label></p>' +
      '<h3>DMs and group DMs <span class="muted">(none picked: every DM)</span></h3>' + pickedList('dms', c.dms || []) + (dms.note ? '<p class="muted">' + esc(dms.note) + '</p>' : picker('dms', 'DM')) +
      '<h3>Channels</h3>' + pickedList('channels', c.channels || []) + (channels.note ? '<p class="muted">' + esc(channels.note) + '</p>' : picker('channels', 'channel')) +
      '<p><label class="field wide">people (ship to body id, JSON; a person body with a ship needs no row) <textarea name="people" rows="3">' + esc(people) + '</textarea></label></p>' +
      '<p><label class="box"><input type="checkbox" name="read_own"' + (c.read_own ? ' checked' : '') + '> read my own messages too</label> ' +
      '<label class="box"><input type="checkbox" name="send_dms"' + (c.send_dms ? ' checked' : '') + '> send approved chat messages as DMs (needs the kernel\'s DM marc; off, the client sends them)</label> ' +
      '<label class="field">every (minutes) <input name="poll_minutes" value="' + esc(c.poll_minutes != null ? c.poll_minutes : '') + '"></label> ' +
      '<label class="field">first look back (hours) <input name="backfill_hours" value="' + esc(c.backfill_hours != null ? c.backfill_hours : '') + '"></label></p>' +
      '<p><label class="field">gate (hundredths) <input name="gate" value="' + esc(c.gate != null ? c.gate : '') + '"></label> ' +
      '<label class="field">escalate (hundredths) <input name="escalate" value="' + esc(c.escalate != null ? c.escalate : '') + '"></label> ' +
      '<label class="field">messages per day at most <input name="max_daily_messages" value="' + esc(c.max_daily_messages != null ? c.max_daily_messages : '') + '"></label> ' +
      '<label class="field">reader model <input name="model" value="' + esc(c.model || '') + '"></label></p>' +
      '<p><button data-save-chat="1">save chat</button><button data-chat-wake="1">read now</button></p></div>';
    if (last.at) {
      out += '<p class="muted">Last pass at ' + fmtTime(last.at) + ', from ' + fmtTime(last.since) + ': ' + (last.conversations || 0) + ' conversations changed' + (last.unpicked ? ' (' + last.unpicked + ' not picked)' : '') + ', ' + (last.changed || 0) + ' messages' + (last.own ? ' (' + last.own + ' of your own left unread)' : '') + '; read ' + (last.read || 0) + ', filed ' + (last.filed || 0) + ', strangers ' + (last.strangers || 0) + ', held ' + (last.held || 0) + '. Read today: ' + (last.read_today || 0) + '.</p>';
      (last.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    if (last.down && last.down.at) {
      out += '<p class="bad">The model could not be read at ' + fmtTime(last.down.at) + '; the pass stopped there and retries on the next tick. Fix the model or the key and press read now.</p>';
      (last.down.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    return out + '</div>';
  }
  // the mail card: the reader's settings and its last pass; the brief
  // card: the last one sent and a button that sends one now
  function mailCard(c, last) {
    c = c || {}; last = last || {};
    var out = '<div class="card"><h2>Mail</h2><div id="mail">' +
      '<p><label class="box"><input type="checkbox" name="enabled"' + (c.enabled ? ' checked' : '') + '> on: the ship reads the mail auspex holds every few minutes, and your replies to the daily brief</label></p>' +
      '<p><label class="field">every (minutes) <input name="poll_minutes" value="' + esc(c.poll_minutes != null ? c.poll_minutes : '') + '"></label> ' +
      '<label class="field">first look back (hours) <input name="backfill_hours" value="' + esc(c.backfill_hours != null ? c.backfill_hours : '') + '"></label> ' +
      '<label class="field">gate (hundredths) <input name="gate" value="' + esc(c.gate != null ? c.gate : '') + '"></label> ' +
      '<label class="field">escalate (hundredths) <input name="escalate" value="' + esc(c.escalate != null ? c.escalate : '') + '"></label> ' +
      '<label class="field">messages per day at most <input name="max_daily_messages" value="' + esc(c.max_daily_messages != null ? c.max_daily_messages : '') + '"></label> ' +
      '<label class="field">reader model <input name="model" value="' + esc(c.model || '') + '"></label></p>' +
      '<p><button data-save-mail="1">save mail</button><button data-mail-wake="1">read now</button></p></div>';
    if (last.at) {
      out += '<p class="muted">Last pass at ' + fmtTime(last.at) + ', from ' + fmtTime(last.since) + ': ' + (last.conversations || 0) + ' threads, ' + (last.changed || 0) + ' messages; read ' + (last.read || 0) + ', filed ' + (last.filed || 0) + ', strangers ' + (last.strangers || 0) + ', held ' + (last.held || 0) + '. Read today: ' + (last.read_today || 0) + '.</p>';
      (last.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    if (last.down && last.down.at) {
      out += '<p class="bad">The model could not be read at ' + fmtTime(last.down.at) + '; the pass stopped there and retries on the next tick.</p>';
      (last.down.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    return out + '</div>';
  }
  function readCard(c, last) {
    c = c || {}; last = last || {};
    var out = '<div class="card"><h2>Read</h2><div id="read"><p class="muted">What a client hands the ship to read (a page from the browser extension, a note) goes through the reader like a message: ' +
      'facts with the page as their source, proposals to approve. A key with write posts it to /api/read.</p>' +
      '<p><label class="box"><input type="checkbox" name="enabled"' + (c.enabled ? ' checked' : '') + '> on</label> ' +
      '<label class="field">gate (hundredths) <input name="gate" value="' + esc(c.gate != null ? c.gate : '') + '"></label> ' +
      '<label class="field">escalate (hundredths) <input name="escalate" value="' + esc(c.escalate != null ? c.escalate : '') + '"></label> ' +
      '<label class="field">texts per day at most <input name="max_daily_messages" value="' + esc(c.max_daily_messages != null ? c.max_daily_messages : '') + '"></label> ' +
      '<label class="field">reader model <input name="model" value="' + esc(c.model || '') + '"></label></p>' +
      '<p><button data-save-read="1">save read</button><button data-read-wake="1">read now</button></p></div>';
    if (last.at) {
      out += '<p class="muted">Last read at ' + fmtTime(last.at) + ': read ' + (last.read || 0) + ', filed ' + (last.filed || 0) + '. Read today: ' + (last.read_today || 0) + '.</p>';
      (last.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    if (last.down && last.down.at) {
      out += '<p class="bad">The model could not be read at ' + fmtTime(last.down.at) + '; the text waits and is tried again in five minutes.</p>';
      (last.down.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    return out + '</div>';
  }
  function briefCard(last) {
    last = last || {};
    var out = '<div class="card"><h2>Daily brief</h2><p class="muted">At seven on your clock the ship mails you the day: the calendar, the actions waiting on you under tags, and the analyst\'s few lines. ' +
      'Reply with "approve A1", "dismiss A2", "A3 done" or "A1 due friday", and anything else you write is a fact in your words; the mail reader reads the reply.</p>' +
      '<p><button data-brief-wake="1">send one now</button></p>';
    if (last.at) {
      out += '<p class="muted">Last brief for ' + esc(last.day || '') + ' at ' + fmtTime(last.at) + (last.sent ? ', sent' : ', not sent') + '; ' + Object.keys(last.tags || {}).length + ' actions tagged.</p>';
      (last.notes || []).forEach(function (n) { out += '<p class="muted">' + esc(n) + '</p>'; });
    }
    return out + '</div>';
  }
  function settings(schema, policy, generator, last, reconcile, telegram, telegramLast, execLast, chat, chatLast, dms, channels, calLast, mail, mailLast, briefLast, read, readLast) {
    return '<h1>Settings</h1>' + generatorCard(generator, last) + reconcileCard(reconcile) + executorCard(execLast, calLast) + telegramCard(telegram, telegramLast) + chatCard(chat, chatLast, dms, channels) + mailCard(mail, mailLast) + readCard(read, readLast) + briefCard(briefLast) +
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
    seg: seg, route: route, sseEvent: sseEvent, graphOf: graphOf, nodePane: nodePane, edgePane: edgePane,
  };
  if (typeof module !== 'undefined' && module.exports) { module.exports = render; }
  if (typeof document === 'undefined') { return; }

  // ---- the app ----

  // ---- the graph: a force layout in three dimensions, drawn on a
  // canvas, turned by dragging. Positions live across refreshes so the
  // beacon's redraw does not scatter what the owner was looking at.
  // ponytail: the repulsion is every pair, fine to a thousand bodies;
  // a grid when it shows.
  var graphPos = Object.create(null), graphView = { rx: -0.35, ry: 0.6, zoom: 1, picked: null, past: false, spin: true }, graphTimer = null, graphState = null;
  function mountGraph(state) {
    graphState = state;
    var canvas = document.getElementById('graph');
    if (!canvas) return;
    var pane = document.getElementById('graph-pane'), find = document.getElementById('graph-find'), pastBox = document.getElementById('graph-past');
    pastBox.checked = graphView.past;
    var g = graphOf(state, graphView.past), ctx = canvas.getContext('2d');
    var ids = Object.create(null);
    g.nodes.forEach(function (n, i) {
      ids[n.id] = true;
      if (!graphPos[n.id]) {
        var t = i * 2.399, r = 120 + 60 * Math.sqrt(i);
        graphPos[n.id] = { x: r * Math.cos(t), y: (i % 7 - 3) * 40, z: r * Math.sin(t), vx: 0, vy: 0, vz: 0 };
      }
      n.p = graphPos[n.id];
    });
    Object.keys(graphPos).forEach(function (id) { if (!ids[id]) delete graphPos[id]; });
    var steps = 0, hot = 160, drag = null, moved = false, proj = [];
    function step() {
      if (steps >= hot) return;
      steps += 1;
      var k = 0.02 * (1 - steps / hot) + 0.002;
      for (var i = 0; i < g.nodes.length; i++) {
        var a = g.nodes[i].p;
        for (var j = i + 1; j < g.nodes.length; j++) {
          var b = g.nodes[j].p, dx = a.x - b.x, dy = a.y - b.y, dz = a.z - b.z, d2 = dx * dx + dy * dy + dz * dz + 1, f = 9000 / d2;
          if (f > 40) f = 40;
          var d = Math.sqrt(d2);
          dx = dx / d * f; dy = dy / d * f; dz = dz / d * f;
          a.vx += dx; a.vy += dy; a.vz += dz; b.vx -= dx; b.vy -= dy; b.vz -= dz;
        }
        a.vx -= a.x * 0.01; a.vy -= a.y * 0.01; a.vz -= a.z * 0.01;
      }
      g.edges.forEach(function (e) {
        var a = g.byId[e.from].p, b = g.byId[e.to].p, dx = b.x - a.x, dy = b.y - a.y, dz = b.z - a.z, d = Math.sqrt(dx * dx + dy * dy + dz * dz) + 0.01, f = (d - 90) * 0.02;
        dx = dx / d * f; dy = dy / d * f; dz = dz / d * f;
        a.vx += dx; a.vy += dy; a.vz += dz; b.vx -= dx; b.vy -= dy; b.vz -= dz;
      });
      g.nodes.forEach(function (n) {
        var p = n.p;
        p.x += p.vx * k * 10; p.y += p.vy * k * 10; p.z += p.vz * k * 10;
        p.vx *= 0.6; p.vy *= 0.6; p.vz *= 0.6;
      });
    }
    function size() {
      var w = canvas.clientWidth || 600, h = canvas.clientHeight || 480, dpr = window.devicePixelRatio || 1;
      if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) { canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr); }
      return { w: w, h: h, dpr: dpr };
    }
    function project(p, s) {
      var cy = Math.cos(graphView.ry), sy = Math.sin(graphView.ry), cx = Math.cos(graphView.rx), sx = Math.sin(graphView.rx);
      var x = p.x * cy + p.z * sy, z = -p.x * sy + p.z * cy, y = p.y * cx - z * sx; z = p.y * sx + z * cx;
      var f = 700 / (700 + z), scale = graphView.zoom * Math.min(s.w, s.h) / 700;
      return { x: s.w / 2 + x * f * scale, y: s.h / 2 + y * f * scale, f: f, z: z };
    }
    function draw() {
      var s = size();
      ctx.setTransform(s.dpr, 0, 0, s.dpr, 0, 0);
      ctx.clearRect(0, 0, s.w, s.h);
      proj = g.nodes.map(function (n) { return project(n.p, s); });
      var pickedId = graphView.picked && graphView.picked.id, pickedEdge = graphView.picked && graphView.picked.attr ? graphView.picked : null;
      var near = Object.create(null);
      if (pickedId) g.edges.forEach(function (e) { if (e.from === pickedId) near[e.to] = true; if (e.to === pickedId) near[e.from] = true; });
      g.edges.forEach(function (e) {
        var a = proj[g.nodes.indexOf(g.byId[e.from])], b = proj[g.nodes.indexOf(g.byId[e.to])];
        var lit = pickedEdge === e || e.from === pickedId || e.to === pickedId;
        ctx.strokeStyle = lit ? '#101541' : 'rgba(16,21,65,' + (0.12 + 0.25 * Math.min(a.f, b.f)) + ')';
        ctx.lineWidth = lit ? 2 : 1;
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
        if (lit) { ctx.fillStyle = '#6b6f80'; ctx.font = '11px system-ui'; ctx.fillText(e.attr, (a.x + b.x) / 2 + 4, (a.y + b.y) / 2 - 4); }
      });
      var order = g.nodes.map(function (n, i) { return i; }).sort(function (i, j) { return proj[j].z - proj[i].z; });
      order.forEach(function (i) {
        var n = g.nodes[i], p = proj[i], r = (4 + Math.min(n.degree, 12) * 0.9) * p.f * graphView.zoom;
        var dim = pickedId && n.id !== pickedId && !near[n.id];
        ctx.globalAlpha = dim ? 0.35 : 1;
        ctx.fillStyle = KIND_COLORS[n.kind] || '#6b7280';
        if (n.closed) ctx.fillStyle = '#c9cbd4';
        ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, Math.PI * 2); ctx.fill();
        if (n.id === pickedId) { ctx.lineWidth = 3; ctx.strokeStyle = '#101541'; ctx.stroke(); }
        if (n.id === pickedId || near[n.id] || (!pickedId && n.degree >= 4) || g.nodes.length <= 30) {
          ctx.fillStyle = '#101541'; ctx.font = (n.id === pickedId ? 'bold ' : '') + '12px system-ui';
          ctx.fillText(n.name.length > 28 ? n.name.slice(0, 27) + '…' : n.name, p.x + r + 3, p.y + 4);
        }
        ctx.globalAlpha = 1;
      });
    }
    function loop() {
      step();
      if (graphView.spin && !drag) graphView.ry += 0.002;
      draw();
      graphTimer = requestAnimationFrame(loop);
    }
    function hit(x, y) {
      var best = null, bd = 12;
      g.nodes.forEach(function (n, i) { var p = proj[i], d = Math.hypot(p.x - x, p.y - y); if (d < bd) { bd = d; best = n; } });
      if (best) return best;
      var be = null, ed = 8;
      g.edges.forEach(function (e) {
        var a = proj[g.nodes.indexOf(g.byId[e.from])], b = proj[g.nodes.indexOf(g.byId[e.to])];
        var l2 = (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y); if (!l2) return;
        var t = Math.max(0, Math.min(1, ((x - a.x) * (b.x - a.x) + (y - a.y) * (b.y - a.y)) / l2));
        var d = Math.hypot(a.x + t * (b.x - a.x) - x, a.y + t * (b.y - a.y) - y);
        if (d < ed) { ed = d; be = e; }
      });
      return be;
    }
    function pick(what) {
      graphView.picked = what;
      graphView.spin = !what;
      if (!what) pane.innerHTML = '<p class="muted">Nothing picked. Click a body or a line between two.</p>';
      else pane.innerHTML = what.attr ? edgePane(what, g) : nodePane(what, g);
    }
    function pos(ev) { var r = canvas.getBoundingClientRect(), t = ev.touches ? ev.touches[0] : ev; return { x: t.clientX - r.left, y: t.clientY - r.top }; }
    canvas.onmousedown = canvas.ontouchstart = function (ev) { drag = pos(ev); moved = false; };
    window.onmousemove = window.ontouchmove = function (ev) {
      if (!drag) return;
      var p = pos(ev), dx = p.x - drag.x, dy = p.y - drag.y;
      if (Math.abs(dx) + Math.abs(dy) > 3) moved = true;
      graphView.ry += dx * 0.008; graphView.rx += dy * 0.008; drag = p;
    };
    window.onmouseup = window.ontouchend = function (ev) {
      if (!drag) return;
      if (!moved) { var p = drag; pick(hit(p.x, p.y)); }
      drag = null;
    };
    canvas.onwheel = function (ev) { ev.preventDefault(); graphView.zoom = Math.max(0.3, Math.min(4, graphView.zoom * (ev.deltaY > 0 ? 0.9 : 1.1))); };
    pane.onclick = function (ev) {
      var a = ev.target.closest('[data-pick]'); if (!a) return;
      ev.preventDefault(); var n = g.byId[a.dataset.pick]; if (n) pick(n);
    };
    find.oninput = function () {
      var q = find.value.trim().toLowerCase(); if (!q) return;
      var n = g.nodes.filter(function (n) { return n.name.toLowerCase().indexOf(q) >= 0 || n.id.indexOf(q) >= 0; })[0];
      if (n) pick(n);
    };
    pastBox.onchange = function () { graphView.past = pastBox.checked; unmountGraph(); mountGraph(graphState); };
    if (graphView.picked) { var again = g.byId[graphView.picked.id]; pick(again || null); }
    unmountGraph();
    graphTimer = requestAnimationFrame(loop);
  }
  function unmountGraph() { if (graphTimer) cancelAnimationFrame(graphTimer); graphTimer = null; }
  var view = document.getElementById('view');
  var statusEl = document.getElementById('status');
  var countEl = document.getElementById('inbox-count');
  var lastRev = null;
  var minted = null;

  function say(msg, bad) { statusEl.textContent = msg; statusEl.className = 'status' + (bad ? ' bad' : ''); }
  function oops(e) { say(e.message, true); }
  function api(path, opts) {
    return fetch(API + path, Object.assign({ cache: 'no-store' }, opts || {})).then(function (r) {
      if (!r.ok) {
        return r.json().catch(function () { return {}; }).then(function (d) {
          // a refusal relayed from Telegram carries its description, not an error
          throw new Error(d.error || d.description || ('http ' + r.status));
        });
      }
      return r.json();
    });
  }
  function post(path, bodyObj, method) {
    return api(path, { method: method || 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(bodyObj) });
  }

  var refreshing = false, again = false;
  function refresh(force) {
    if (refreshing) { again = true; return; }
    if (editing() && !force) { say('not refreshed: a form holds unsaved changes'); return; }
    refreshing = true;
    var r = route(location.hash);
    var p;
    if (r.name !== 'keys') minted = null;
    var proposed = null;
    function state() {
      return api('/state').then(function (s) {
        if (typeof s.rev === 'number') lastRev = String(s.rev);
        proposed = (s.actions || []).filter(function (a) { return a.status === 'proposed'; }).length;
        return s;
      });
    }
    if (r.name !== 'bodies') unmountGraph();
    if (r.name === 'body') p = Promise.all([api('/body/' + seg(r.id)), state()]).then(function (d) { view.innerHTML = body(d[0], d[1]); });
    else if (r.name === 'inbox') p = Promise.all([api('/actions?status=open'), state()]).then(function (d) { view.innerHTML = inbox(d[0], d[1]); });
    else if (r.name === 'settings') p = Promise.all([api('/schema'), api('/policy'), api('/generator'), api('/generator/last'), api('/reconcile/last'), api('/telegram'), api('/telegram/last'), api('/exec/last'), api('/chat'), api('/chat/last'), api('/chat/lists'), api('/calendar/last'), api('/mail'), api('/mail/last'), api('/brief/last'), api('/read/settings'), api('/read/last')]).then(function (d) { var lists = d[10] || {}; view.innerHTML = settings(d[0], d[1], d[2], d[3], d[4], d[5], d[6], d[7], d[8], d[9], lists.dms, lists.channels, d[11], d[12], d[13], d[14], d[15], d[16]); });
    else if (r.name === 'keys') p = Promise.all([api('/clients'), api('/schema')]).then(function (d) { view.innerHTML = keys(d[0], d[1], minted); });
    else p = state().then(function (s) { view.innerHTML = bodies(s); mountGraph(s); });
    // the state view carries every open action, so a view that read it
    // has the count already; only settings and keys ask for it
    p = p.then(function () { return proposed === null ? api('/actions?status=proposed').then(function (a) { return a.length; }) : proposed; }).then(function (n) {
      countEl.textContent = n ? String(n) : '';
      say('');
    }).catch(function (e) { say(String(e.message || e), true); });
    p.then(function () { refreshing = false; if (again) { again = false; refresh(); } });
  }

  // a write answers before the writer applies, so the refetch waits
  // after a move: a note half-typed under another action is kept, so the
  // refresh waits for it rather than wiping it
  function typedNote() { return Array.prototype.some.call(view.querySelectorAll('[data-refine-text]'), function (i) { return !!i.value.trim(); }); }
  function later() { dirty = typedNote(); setTimeout(function () { refresh(!dirty); }, 300); }

  view.addEventListener('click', function (ev) {
    var b = ev.target.closest('button');
    if (!b) return;
    if (b.dataset.retract) {
      var note = prompt('Why retract this observation?');
      if (note === null) return;
      post('/retract', { id: b.dataset.retract, note: note, by: 'page' }).then(later).catch(oops);
    } else if (b.dataset.move) {
      var cut = b.dataset.move.indexOf(':');
      var moveId = b.dataset.move.slice(0, cut), moveTo = b.dataset.move.slice(cut + 1);
      var move = { status: moveTo, by: 'page' };
      if (moveTo === 'dismissed') {
        // the reason rides in the note and reaches the generator's prompt
        // with the decision, where it teaches taste, not just this title;
        // a dismissal without one teaches nothing, so one is required
        var why = prompt('Why? A few words teach the generator: "just the event", "I always do this", "not mine to do", "already done".');
        if (why === null) return;
        if (!why.trim()) { say('a reason is needed to dismiss: it is what the generator learns from', true); return; }
        move.note = why.trim().slice(0, 500);
      }
      post('/actions/' + seg(moveId), move).then(later).catch(oops);
    } else if (b.dataset.refine) {
      var rid = b.dataset.refine;
      // The row is looked up fresh each time, since the writer's revision
      // moves the beacon while the request runs and the redraw replaces the row.
      var noteOf = function () { return view.querySelector('[data-refine-note="' + rid + '"]'); };
      var textOf = function () { return view.querySelector('[data-refine-text="' + rid + '"]'); };
      // The row's move buttons are held while the note is applied: an
      // approval in that window would move the action the revision is
      // aimed at, and the ship would answer that it moved.
      var holdMoves = function (held) {
        Array.prototype.forEach.call(view.querySelectorAll('[data-move^="' + rid + ':"]'), function (m) { m.disabled = held; });
      };
      var input = textOf(), noteEl = noteOf();
      var text = input ? input.value.trim() : '';
      if (!text) { if (noteEl) noteEl.textContent = 'type a note first'; return; }
      b.disabled = true;
      holdMoves(true);
      if (noteEl) noteEl.textContent = 'refining';
      post('/actions/' + seg(rid) + '/refine', { text: text }).then(function (d) {
        var el = noteOf(), inp = textOf();
        if (d && d.ok) {
          if (el) el.textContent = 'revised' + (d.note ? ': ' + d.note : '');
          // The box's own text is spent, so only another box still typing
          // holds the page unsaved, and the revised row is fetched at once.
          if (inp) { inp.value = ''; inp.blur(); }
          dirty = Array.prototype.some.call(view.querySelectorAll('[data-refine-text]'), function (i) { return !!i.value.trim(); });
          refresh(true);
        } else if (el) el.textContent = (d && d.note) || 'not refined';
        b.disabled = false;
        holdMoves(false);
      }).catch(function (e) { var el = noteOf(); if (el) el.textContent = e.message; b.disabled = false; holdMoves(false); });
    } else if (b.dataset.save) {
      var which = b.dataset.save;
      var parsed;
      try { parsed = JSON.parse(document.getElementById(which).value); } catch (e) { say(which + ': ' + e.message, true); return; }
      post('/' + which, parsed, 'PUT').then(function () { say(which + ' saved'); dirty = false; }).catch(oops);
    } else if (b.dataset.revoke) {
      if (!confirm('Revoke "' + b.dataset.name + '"? Its next request is refused.')) return;
      api('/clients/' + seg(b.dataset.revoke), { method: 'DELETE' }).then(later).catch(oops);
    } else if (b.dataset.mint) {
      post('/clients', mintForm()).then(function (d) { minted = d; dirty = false; refresh(true); }).catch(oops);
    } else if (b.dataset.copy) {
      var text = document.getElementById(b.dataset.copy).textContent;
      if (!navigator.clipboard) { say('copy by hand: the browser offers no clipboard here', true); return; }
      navigator.clipboard.writeText(text).then(function () { say('copied'); }, function () { say('copy failed: select it by hand', true); });
    } else if (b.dataset.dismissToken) {
      minted = null;
      dirty = false;
      refresh(true);
    } else if (b.dataset.saveGenerator) {
      say('saving generator settings');
      post('/generator', generatorForm(), 'PUT').then(function () { dirty = false; say('generator saved'); }).catch(oops);
    } else if (b.dataset.generate) {
      post('/generate', {}).then(function () { say('pass started; the last pass line updates when it ends'); setTimeout(refresh, 30000); }).catch(oops);
    } else if (b.dataset.reconcile) {
      post('/reconcile', {}).then(function () { say('reconcile started; the last run line updates when it ends'); setTimeout(refresh, 15000); }).catch(oops);
    } else if (b.dataset.saveTelegram) {
      var t = telegramForm();
      if (!t) return;
      say('saving telegram settings');
      b.disabled = true;
      post('/telegram', t, 'PUT').then(function () {
        // the fields already hold what was saved; only the two masks are
        // read back, so the card is right at once and the full reload
        // (six requests, a second each on the ship) comes later
        var tok = view.querySelector('#telegram input[name="token"]'), sec = view.querySelector('#telegram input[name="secret"]');
        if (tok && t.token) { tok.value = ''; tok.placeholder = 'a token is set; leave blank to keep it'; }
        if (sec && t.secret) { sec.value = ''; sec.placeholder = 'a secret is set; leave blank to keep it'; }
        dirty = false;
        say('telegram saved');
        b.disabled = false;
      }).catch(function (e) { say(e.message, true); b.disabled = false; });
    } else if (b.dataset.pick) {
      var kind = b.dataset.pick, ul = view.querySelector('[data-picked="' + kind + '"]');
      var empty = ul.querySelector('[data-empty]'); if (empty) empty.remove();
      var item = chatLists[kind].filter(function (x) { return x.id === b.dataset.id; })[0] || { id: b.dataset.id };
      var li = document.createElement('li'); li.dataset.id = item.id;
      li.innerHTML = labelOf(item) + ' <button class="small" data-unpick="' + kind + '">remove</button>';
      ul.appendChild(li); dirty = true;
      var find = view.querySelector('#chat input[name="' + kind + '-find"]');
      view.querySelector('[data-matches="' + kind + '"]').innerHTML = matchesHtml(kind, find ? find.value : '');
    } else if (b.dataset.unpick) {
      var k2 = b.dataset.unpick, ul2 = b.closest('ul');
      b.closest('li').remove(); dirty = true;
      if (!ul2.querySelector('li[data-id]')) ul2.innerHTML = '<li class="muted" data-empty="1">none picked</li>';
      var find2 = view.querySelector('#chat input[name="' + k2 + '-find"]');
      view.querySelector('[data-matches="' + k2 + '"]').innerHTML = matchesHtml(k2, find2 ? find2.value : '');
    } else if (b.dataset.saveChat) {
      var c = chatForm();
      if (!c) return;
      say('saving chat settings');
      post('/chat', c, 'PUT').then(function () { dirty = false; say('chat saved'); refresh(true); }).catch(oops);
    } else if (b.dataset.chatWake) {
      post('/chat/wake', {}).then(function () { say('reader woken; the card updates when the pass ends'); setTimeout(function () { refresh(true); }, 15000); }).catch(oops);
    } else if (b.dataset.saveMail) {
      var mc = { enabled: !!view.querySelector('#mail input[name="enabled"]:checked'), model: field('#mail', 'model') };
      ['poll_minutes', 'backfill_hours', 'gate', 'escalate', 'max_daily_messages'].forEach(function (k) { var n = parseInt(field('#mail', k), 10); mc[k] = isNaN(n) ? null : n; });
      say('saving mail settings');
      post('/mail', mc, 'PUT').then(function () { dirty = false; say('mail saved'); refresh(true); }).catch(oops);
    } else if (b.dataset.saveRead) {
      var rc = { enabled: !!view.querySelector('#read input[name="enabled"]:checked'), model: field('#read', 'model') };
      ['gate', 'escalate', 'max_daily_messages'].forEach(function (k) { var n = parseInt(field('#read', k), 10); rc[k] = isNaN(n) ? null : n; });
      say('saving read settings');
      post('/read/settings', rc, 'PUT').then(function () { dirty = false; say('read saved'); refresh(true); }).catch(oops);
    } else if (b.dataset.readWake) {
      post('/read/wake', {}).then(function () { say('reader woken'); setTimeout(function () { refresh(true); }, 8000); }).catch(oops);
    } else if (b.dataset.mailWake) {
      post('/mail/wake', {}).then(function () { say('mail reader woken; the card updates when the pass ends'); setTimeout(function () { refresh(true); }, 15000); }).catch(oops);
    } else if (b.dataset.briefWake) {
      post('/brief/wake', {}).then(function () { say('brief on its way; the card updates when it is sent'); setTimeout(function () { refresh(true); }, 15000); }).catch(oops);
    } else if (b.dataset.webhook) {
      say('asking Telegram to send updates here');
      post('/telegram/webhook', {}).then(function (d) { say(d && d.ok ? 'webhook registered' : 'telegram said: ' + (d && d.description), !(d && d.ok)); }).catch(oops);
    } else if (b.dataset.wake) {
      post('/telegram/wake', {}).then(function () { say('reader woken; the card updates when it has read'); setTimeout(function () { refresh(true); }, 20000); }).catch(oops);
    } else if (b.dataset.execWake) {
      // the pass follows within a second or two, so the card is read back soon after
      say('waking the executor');
      post('/exec/wake', {}).then(function () { say('executor woken; the card updates when the pass ends'); setTimeout(function () { refresh(true); }, 5000); }).catch(oops);
    } else if (b.dataset.webhookInfo) {
      say('asking Telegram');
      api('/telegram/webhook').then(function (d) {
        var el = document.getElementById('webhook-info');
        if (!el) return;
        var when = d.last_error_date ? new Date(d.last_error_date * 1000).toISOString().replace('T', ' ').slice(0, 19) : '';
        el.textContent = 'Telegram holds url ' + (d.url || '(none: not registered)') + '; ' + (d.pending_update_count || 0) + ' updates waiting' +
          (d.last_error_message ? '; last delivery error ' + when + ': ' + d.last_error_message : '; no delivery error') + '.';
        say('');
      }).catch(oops);
    } else if (b.dataset.makeSecret) {
      // a fresh secret: 32 random bytes as hex, in the field until saved
      var bytes = new Uint8Array(32);
      crypto.getRandomValues(bytes);
      var hex = Array.prototype.map.call(bytes, function (x) { return (x < 16 ? '0' : '') + x.toString(16); }).join('');
      var secretEl = view.querySelector('#telegram input[name="secret"]');
      if (secretEl) { secretEl.value = hex; say('a secret is in the field; save telegram to keep it'); }
    }
  });
  // the generator form as the API takes it; a blank key is left out so
  // the stored one stays; "off" reasoning is {"enabled": false}
  function field(scope, name) { var el = view.querySelector(scope + ' [name="' + name + '"]'); return el ? el.value.trim() : ''; }
  // a number left blank is sent as null, which clears the stored one so
  // the ship's default stands; a 0 there would stop the generator or hold
  // every message for good
  function numOrNull(v) { var n = parseInt(v, 10); return isNaN(n) ? null : n; }
  function generatorForm() {
    var val = function (name) { return field('#generator', name); };
    var effort = val('effort').toLowerCase();
    var g = { enabled: !!view.querySelector('#generator input[name="enabled"]:checked'), url: val('url'), model: val('model'),
      reasoning: effort === 'off' ? { enabled: false } : { effort: effort || 'high' },
      max_tokens: numOrNull(val('max_tokens')), max_actions: numOrNull(val('max_actions')),
      cooldown_minutes: numOrNull(val('cooldown_minutes')), max_daily: numOrNull(val('max_daily')),
      max_urgent: numOrNull(val('max_urgent')) };
    if (val('api_key')) g.api_key = val('api_key');
    return g;
  }
  // the telegram form as the API takes it; a blank token or secret is left
  // out so the stored one stays; people is JSON, and a parse error stops the
  // save with the message, so the form answers null
  function telegramForm() {
    var val = function (name) { return field('#telegram', name); };
    var people;
    try { people = JSON.parse(val('people') || '{}'); } catch (e) { say('people: ' + e.message, true); return null; }
    var t = { enabled: !!view.querySelector('#telegram input[name="enabled"]:checked'), public_url: val('public_url'), model: val('model'),
      chats: val('chats').split(',').map(function (c) { return c.trim(); }).filter(Boolean), people: people,
      gate: numOrNull(val('gate')), escalate: numOrNull(val('escalate')),
      max_daily_messages: numOrNull(val('max_daily_messages')) };
    if (val('token')) t.token = val('token');
    if (val('secret')) t.secret = val('secret');
    return t;
  }
  // the chat form as the API takes it: the typed lists plus the boxes
  // ticked beside them; people is JSON, and a parse error stops the save
  function chatForm() {
    var val = function (name) { return field('#chat', name); };
    function list(name) {
      return Array.prototype.map.call(view.querySelectorAll('#chat [data-picked="' + name + '"] li[data-id]'), function (li) { return li.dataset.id; });
    }
    var people;
    try { people = JSON.parse(val('people') || '{}'); } catch (e) { say('people: ' + e.message, true); return null; }
    var c = { enabled: !!view.querySelector('#chat input[name="enabled"]:checked'), dms: list('dms'), channels: list('channels'), people: people,
      read_own: !!view.querySelector('#chat input[name="read_own"]:checked'), send_dms: !!view.querySelector('#chat input[name="send_dms"]:checked'), model: val('model') };
    // a number left blank is sent as null, which clears the stored one
    // so the ship's default stands, never a zero that would hold every message
    ['poll_minutes', 'backfill_hours', 'gate', 'escalate', 'max_daily_messages'].forEach(function (k) {
      var n = parseInt(val(k), 10);
      c[k] = isNaN(n) ? null : n;
    });
    return c;
  }
  // the mint form as the API takes it; sensitive: write only rides with write
  function mintForm() {
    var val = function (name) { return field('#mint', name); };
    function picked(name) {
      return Array.prototype.map.call(view.querySelectorAll('#mint input[name="' + name + '"]:checked'), function (el) { return el.value; });
    }
    var write = picked('write').length > 0;
    return { name: val('name'), by: val('by'),
      scope: { kinds: picked('kinds'), actions: picked('actions'), write: write, sensitive: write && picked('sensitive').length ? 'write' : 'none' } };
  }
  view.addEventListener('input', function (e) {
    var el = e.target;
    if (!el || !el.name || el.name.slice(-5) !== '-find') return;
    var kind = el.name.slice(0, -5);
    var box = view.querySelector('[data-matches="' + kind + '"]');
    if (box) box.innerHTML = matchesHtml(kind, el.value);
  });
  window.addEventListener('hashchange', function () { dirty = false; refresh(true); });
  document.addEventListener('visibilitychange', function () { if (!document.hidden) refresh(); });

  // ---- the beacon stream, read raw (the initial event is named "old
  // /rev", which EventSource cannot subscribe to; it carries the current
  // rev, so a bump missed while nobody watched shows as a difference) ----
  var timer = null;
  // a re-render replaces every form on the page, so it waits while a
  // field has focus or while any field holds what has not been saved:
  // a token pasted into the telegram card was lost to a timed refresh
  // after a tab switch (2026-09-21). Saving clears the mark.
  var dirty = false;
  // Enter in a refine box presses its button.
  view.addEventListener('keydown', function (e) {
    var el = e.target;
    if (e.key !== 'Enter' || !el || !el.dataset || !el.dataset.refineText) return;
    var btn = view.querySelector('[data-refine="' + el.dataset.refineText + '"]');
    // Focus leaves the box before the click, so a redraw is not held by it.
    if (btn) { e.preventDefault(); el.blur(); btn.focus(); btn.click(); }
  });
  view.addEventListener('input', function (e) {
    var el = e.target;
    if (el && (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT')) dirty = true;
  });
  function editing() {
    if (dirty) return true;
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
  refresh(true);
  stream();
  setInterval(function () { if (!document.hidden) refresh(); }, 60000);
})();
