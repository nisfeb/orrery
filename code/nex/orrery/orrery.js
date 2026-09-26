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
  var EVENT_KINDS = { situation: true, activity: true };
  // withEvents false is the relationship diagram: no situation or
  // activity is a node, and two bodies that share events are one line
  // saying how many, beside what else relates them ("son · 25 events")
  function graphOf(state, showPast, withEvents) {
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
    // a person's relationship to the owner ("son", "wife") is text, not a
    // ref, and it is the line a relationship diagram is for
    var me = state.me || 'person/me';
    nodes.forEach(function (n) {
      if (n.kind !== 'person' || n.id === me) return;
      var r = n.body.attrs && n.body.attrs.relationship;
      r = Array.isArray(r) ? r[0] : r;
      if (r && typeof r.value === 'string' && r.value.trim()) edge(me, n.id, r.value.trim(), r.at || '');
    });
    if (withEvents === false) {
      var pairs = Object.create(null), order = [];
      var line = function (from, to) {
        var key = from < to ? from + '|' + to : to + '|' + from;
        if (!pairs[key]) { pairs[key] = { from: from, to: to, words: [], shared: 0, at: '' }; order.push(key); }
        return pairs[key];
      };
      edges.forEach(function (e) {
        if (EVENT_KINDS[byId[e.from].kind] || EVENT_KINDS[byId[e.to].kind]) return;
        var l = line(e.from, e.to);
        if (l.words.indexOf(e.attr) < 0) l.words.push(e.attr);
      });
      nodes.forEach(function (ev) {
        if (!EVENT_KINDS[ev.kind]) return;
        var with_ = [];
        edges.forEach(function (e) {
          var other = e.from === ev.id ? e.to : e.to === ev.id ? e.from : null;
          if (other && !EVENT_KINDS[byId[other].kind] && with_.indexOf(other) < 0) with_.push(other);
        });
        for (var i = 0; i < with_.length; i++) for (var j = i + 1; j < with_.length; j++) line(with_[i], with_[j]).shared += 1;
      });
      nodes.forEach(function (n) { n.degree = 0; });
      edges = order.map(function (key) {
        var l = pairs[key];
        var words = l.words.slice();
        if (l.shared) words.push(l.shared + (l.shared === 1 ? ' event' : ' events'));
        byId[l.from].degree += 1; byId[l.to].degree += 1;
        return { from: l.from, to: l.to, attr: words.join(' \u00b7 '), at: l.at };
      });
      nodes = nodes.filter(function (n) { return !EVENT_KINDS[n.kind]; });
    }
    // a body with no line is off the diagram (scattered round the rest,
    // they read as an orbit); the finder and byId still reach it
    return { nodes: nodes.filter(function (n) { return n.degree > 0; }), all: nodes, edges: edges, byId: byId, me: me };
  }
  // what a line says, read from its first end: a situation's participants
  // are each a participant
  function edgeWord(attr) { return attr === 'participants' ? 'participant' : attr; }
  function bodies(state, gone) {
    var n = (state.bodies || []).length;
    var out = '<h1>Bodies <span class="muted">' + n + '</span></h1>' +
      '<div class="graph-bar"><input id="graph-find" placeholder="find a body by name" aria-label="find a body">' +
      '<label class="box"><input type="checkbox" id="graph-events"> events</label>' +
      '<label class="box"><input type="checkbox" id="graph-past"> past situations</label>' +
      '<span class="muted">tap a body to centre on it; drag to move, pinch or wheel to zoom</span>' +
      '<span class="muted" id="graph-alone"></span></div>' +
      '<div class="graph"><canvas id="graph" aria-label="the bodies and their connections"></canvas>' +
      '<aside id="graph-pane" class="card">' + emptyPane() + '</aside></div>' + tidyCard(state, false, gone);
    if (!n) out += '<p class="muted">Nothing observed yet.</p>';
    return out;
  }
  // bodies that look like one: two of a kind that share a ship (the one
  // whose own ship it is counts most) or a name, a situation's name on
  // the same day only (one title recurs: two ballets are two ballets).
  // Into is the surer body: the owner, else the one whose own ship it
  // is, else the one with more attributes, so the owner is never merged
  // away; and a body with a sure match is offered no weaker one.
  function dayOf(b) {
    var a = b.attrs || {}, r = a.starts || a.started;
    r = Array.isArray(r) ? r[0] : r;
    return r && typeof r.value === 'string' ? r.value.slice(0, 10) : '';
  }
  function dupesOf(state) {
    var me = state.me || 'person/me', groups = Object.create(null), pairs = [], said = Object.create(null);
    function put(k, b, why, strong) { (groups[k] = groups[k] || []).push({ b: b, why: why, strong: strong }); }
    (state.bodies || []).forEach(function (b) {
      if (b.ship) put(b.kind + '|' + String(b.ship).toLowerCase(), b, 'both are ' + b.ship, true);
      (b.aliases || []).forEach(function (a) {
        var t = String(a).trim().toLowerCase();
        if (/^~[a-z]+(-[a-z]+)*$/.test(t)) put(b.kind + '|' + t, b, 'both are ' + t, false);
      });
      var n = String(b.name || '').trim().toLowerCase();
      if (n && n.charAt(0) !== '~') put(b.kind + '|name|' + n + (b.kind === 'situation' ? '|' + dayOf(b) : ''), b, b.kind === 'situation' ? 'the same name, the same day' : 'the same name', false);
    });
    function rank(b) { return (b.id === me ? 1e9 : 0) + (b.ship ? 1e6 : 0) + Object.keys(b.attrs || {}).length; }
    Object.keys(groups).forEach(function (k) {
      var g = groups[k], strong = g.some(function (x) { return x.strong; });
      for (var i = 0; i < g.length; i++) for (var j = i + 1; j < g.length; j++) {
        var a = g[i].b, b = g[j].b;
        if (a.id === b.id) continue;
        var into = rank(a) >= rank(b) ? a : b, from = into === a ? b : a, key = from.id + '|' + into.id;
        if (said[key]) continue;
        said[key] = true;
        pairs.push({ from: from, into: into, why: g[i].why, strong: strong });
      }
    });
    var sure = Object.create(null);
    pairs.forEach(function (p) { if (p.strong) sure[p.from.id] = true; });
    // the owner is merged into only on a ship the other body holds as its
    // own: an alias it carries may be a wrong one a merge brought
    return pairs.filter(function (p) { return (p.strong || !sure[p.from.id]) && (p.into.id !== me || p.strong); })
      .sort(function (x, y) { return (y.strong ? 1 : 0) - (x.strong ? 1 : 0); });
  }
  // what the tidy section offers: each likely duplicate with a merge, and
  // each body with no connection at all with a delete
  function tidyCard(state, open, gone) {
    // what the owner merged or deleted from this page is gone from the
    // list at once, whatever a refresh caught mid-way brings back
    gone = gone || {};
    var dupes = dupesOf(state).filter(function (d) { return !gone[d.from.id] && !gone[d.into.id]; }), g = graphOf(state, true, true);
    var linked = Object.create(null);
    g.nodes.forEach(function (n) { linked[n.id] = true; });
    var loose = g.all.filter(function (n) { return !linked[n.id] && !gone[n.id] && n.id !== (state.me || 'person/me'); });
    if (!dupes.length && !loose.length) return '<div id="tidy"></div>';
    var out = '<details class="card" id="tidy"' + (open ? ' open' : '') + '><summary>Tidy: ' + dupes.length + ' possible duplicate' + (dupes.length === 1 ? '' : 's') +
      ', ' + loose.length + ' with no connection</summary>';
    if (dupes.length) {
      out += '<h3>Possible duplicates</h3><ul class="links">' + dupes.map(function (d) {
        return '<li><a href="#body/' + esc(d.from.id) + '">' + esc(d.from.name || d.from.id) + '</a> into <a href="#body/' + esc(d.into.id) + '">' + esc(d.into.name || d.into.id) + '</a> ' +
          '<span class="muted">' + esc(d.into.kind) + ', ' + esc(d.why) + '</span> <button class="small" data-merge="' + esc(d.from.id) + '" data-into="' + esc(d.into.id) + '">merge</button></li>';
      }).join('') + '</ul>';
    }
    if (loose.length) {
      out += '<h3>No connection</h3><p class="muted">Nothing links these to anything else. Some are worth keeping for what they say; the rest can go.</p><ul class="links">' + loose.map(function (n) {
        var facts = Object.keys(n.body.attrs || {}).length;
        return '<li><a href="#body/' + esc(n.id) + '">' + esc(n.name) + '</a> <span class="muted">' + esc(n.kind) + ' &middot; ' + facts + (facts === 1 ? ' fact' : ' facts') + '</span> ' +
          '<button class="small danger" data-delete-body="' + esc(n.id) + '" data-name="' + esc(n.name) + '">delete</button></li>';
      }).join('') + '</ul>';
    }
    return out + '</details>';
  }
  // the pane with nothing picked: what to do, and what the colours are
  function emptyPane() {
    return '<p class="muted">Nothing picked. Tap a body to centre on it, or a line to see what it says.</p>' +
      '<ul class="legend">' + Object.keys(KIND_COLORS).map(function (k) { return '<li><i style="background:' + KIND_COLORS[k] + '"></i>' + esc(k) + '</li>'; }).join('') + '</ul>';
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
      (v.aliases && v.aliases.length ? ' &middot; also ' + v.aliases.map(function (a) {
        return '<span class="alias">' + esc(a) + '<button class="small" data-unalias="' + esc(a) + '" data-id="' + esc(v.id) + '" aria-label="remove the alias ' + esc(a) + '">&times;</button></span>';
      }).join(' ') : '') + '</p>';
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
  function executorCard(last, cal, policy) {
    last = last || {}; cal = cal || {}; policy = policy || {};
    var out = '<div class="card"><h2>Executor</h2><p class="muted">The ship carries out approved actions itself: a message via telegram through the bot, ' +
      'via mail through auspex to the person\'s ship, a calendar action onto the calendar, a task into its todo list; and it keeps the todo list and the tasks ' +
      'in step both ways. A message via chat is left for the client that sends chat.</p><p><button data-exec-wake="1">wake the executor</button></p>' +
      // which of the calendar's lists they land in; filled from the
      // calendar once the page is drawn
      '<p><label class="field">todos go to <select id="todo-cal" data-now="' + esc(policy.todo_calendar || '') + '"><option value="">the calendar\'s default</option></select></label> ' +
      '<label class="field">calendar events go to <select id="event-cal" data-now="' + esc(policy.event_calendar || '') + '"><option value="">the calendar\'s default</option></select></label> ' +
      '<button data-save-cals="1">save</button></p><p class="muted">Todos stay on your ship: Google Calendar and most CalDAV servers (iCloud among them) do not show them.</p>';
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
  // the owner's style and standing preferences, which every prompt reads,
  // and the reasons they gave for dismissing, each offered as one
  function prefsCard(schema, reasons) {
    schema = schema || {};
    var prefs = Array.isArray(schema.preferences) ? schema.preferences.filter(function (p) { return typeof p === 'string'; }) : [];
    var have = Object.create(null);
    prefs.forEach(function (p) { have[p.trim().toLowerCase()] = true; });
    var out = '<div class="card" id="prefs"><h2>Style and preferences</h2><p class="muted">Every prompt reads these: how anything written in your voice should read, and what you want proposed and what not.</p>' +
      '<label class="block">style<textarea class="short" id="pref-style" rows="3" aria-label="style">' + esc(typeof schema.style === 'string' ? schema.style : '') + '</textarea></label>' +
      '<label class="block">preferences, one a line<textarea class="short" id="pref-list" rows="5" aria-label="preferences">' + esc(prefs.join('\n')) + '</textarea></label>' +
      '<p><button data-save-prefs="1">save style and preferences</button></p>';
    var fresh = (reasons || []).filter(function (r) { return r && r.reason && !have[String(r.reason).trim().toLowerCase()]; });
    if (fresh.length) {
      out += '<h3>Reasons you gave for dismissing</h3><p class="muted">A reason you give again and again is taste: keep it as a preference and every prompt reads it.</p><ul class="links">' +
        fresh.map(function (r) {
          return '<li>' + esc(r.reason) + ' <span class="muted">' + (r.count > 1 ? r.count + ' times' : 'once') + '</span> <button class="small" data-prefer="' + esc(r.reason) + '">keep as a preference</button></li>';
        }).join('') + '</ul>';
    }
    return out + '</div>';
  }
  // how each proposer's actions fared, by kind: what the owner kept,
  // dismissed (and gave a reason for), what waits and what failed
  function qualityCard(tally) {
    if (!tally || !tally.length) return '';
    return '<div class="card"><h2>How proposals fared</h2><table><thead><tr><th>from</th><th>kind</th><th>kept</th><th>dismissed</th><th>waiting</th><th>failed</th><th>kept of decided</th></tr></thead><tbody>' +
      tally.map(function (t) {
        var decided = (t.kept || 0) + (t.dismissed || 0);
        return '<tr><td data-label="from">' + esc(t.by) + '</td><td data-label="kind">' + esc(t.kind) + '</td><td data-label="kept">' + (t.kept || 0) + '</td>' +
          '<td data-label="dismissed">' + (t.dismissed || 0) + (t.reasoned ? ' <span class="muted">(' + t.reasoned + ' with a reason)</span>' : '') + '</td>' +
          '<td data-label="waiting">' + (t.waiting || 0) + '</td><td data-label="failed">' + (t.failed || 0) + '</td>' +
          '<td data-label="kept of decided">' + (decided ? Math.round(100 * (t.kept || 0) / decided) + '%' : '&ndash;') + '</td></tr>';
      }).join('') + '</tbody></table></div>';
  }
  function settings(schema, policy, generator, last, reconcile, telegram, telegramLast, execLast, chat, chatLast, dms, channels, calLast, mail, mailLast, briefLast, read, readLast, reasons, tally) {
    return '<h1>Settings</h1>' + prefsCard(schema, reasons) + generatorCard(generator, last) + qualityCard(tally) + reconcileCard(reconcile) + executorCard(execLast, calLast, policy) + telegramCard(telegram, telegramLast) + chatCard(chat, chatLast, dms, channels) + mailCard(mail, mailLast) + readCard(read, readLast) + briefCard(briefLast) +
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
    seg: seg, route: route, sseEvent: sseEvent, graphOf: graphOf, nodePane: nodePane, edgePane: edgePane, dupesOf: dupesOf, tidyCard: tidyCard, prefsCard: prefsCard, qualityCard: qualityCard,
  };
  if (typeof module !== 'undefined' && module.exports) { module.exports = render; }
  if (typeof document === 'undefined') { return; }

  // ---- the app ----

  // ---- the graph: a relationship diagram, flat, centred on one body
  // (the owner, until another is tapped), each line labelled with what
  // it is. A force layout places the rest: bodies push apart, a line
  // pulls its ends together. Drag moves the diagram, a pinch or the
  // wheel zooms it, a tap on a body centres on it. Positions live across
  // refreshes so the beacon's redraw does not scatter what the owner was
  // looking at, and it is drawn only while something moves. Its colours
  // are the page's own, so it reads in dark mode too.
  // ponytail: the repulsion is every pair, fine to a thousand bodies;
  // a grid when it shows.
  var coarse = !!(window.matchMedia && window.matchMedia('(pointer: coarse)').matches);
  var graphPos = Object.create(null), graphView = { zoom: 1, px: 0, py: 0, picked: null, focus: null, past: false, events: false, touching: 0 }, graphTimer = null, graphState = null;
  function palette() {
    var cs = getComputedStyle(document.documentElement);
    function v(name, dflt) { return (cs.getPropertyValue(name) || '').trim() || dflt; }
    return { ink: v('--ink', '#101541'), muted: v('--muted', '#6b6f80'), card: v('--card', '#ffffff') };
  }
  function mountGraph(state) {
    graphState = state;
    var canvas = document.getElementById('graph');
    if (!canvas) return;
    var pane = document.getElementById('graph-pane'), find = document.getElementById('graph-find'), pastBox = document.getElementById('graph-past'), eventsBox = document.getElementById('graph-events'), aloneEl = document.getElementById('graph-alone');
    pastBox.checked = graphView.past;
    eventsBox.checked = graphView.events;
    // the pane lists every connection, events too, whatever the diagram shows
    var g = graphOf(state, graphView.past, graphView.events), full = graphView.events ? g : graphOf(state, graphView.past), ctx = canvas.getContext('2d');
    var alone = g.all.length - g.nodes.length;
    if (aloneEl) aloneEl.textContent = alone ? alone + ' with no connection: find them by name' : '';
    var at = Object.create(null), added = 0;
    g.nodes.forEach(function (n, i) {
      at[n.id] = i;
      var p = graphPos[n.id];
      if (!p || p.z !== undefined) {
        var t = i * 2.399, r = 40 + 30 * Math.sqrt(i);
        graphPos[n.id] = { x: r * Math.cos(t), y: r * Math.sin(t), vx: 0, vy: 0 };
        added += 1;
      }
      n.p = graphPos[n.id];
    });
    Object.keys(graphPos).forEach(function (id) { if (at[id] === undefined) delete graphPos[id]; });
    if (!graphView.focus || at[graphView.focus] === undefined) graphView.focus = at[g.me] !== undefined ? g.me : null;
    // a refresh that brought no new body leaves the layout as it lies
    var hot = 220, steps = added ? 0 : hot, drag = null, moved = false, proj = [], frames = 0, touchy = coarse;
    function step() {
      if (steps >= hot) return;
      steps += 1;
      var k = 0.02 * (1 - steps / hot) + 0.002, i, j;
      for (i = 0; i < g.nodes.length; i++) {
        var a = g.nodes[i].p;
        for (j = i + 1; j < g.nodes.length; j++) {
          var b = g.nodes[j].p, dx = a.x - b.x, dy = a.y - b.y, d2 = dx * dx + dy * dy + 1, f = 9000 / d2;
          if (f > 40) f = 40;
          var d = Math.sqrt(d2);
          dx = dx / d * f; dy = dy / d * f;
          a.vx += dx; a.vy += dy; b.vx -= dx; b.vy -= dy;
        }
        a.vx -= a.x * 0.01; a.vy -= a.y * 0.01;
      }
      g.edges.forEach(function (e) {
        var a = g.byId[e.from].p, b = g.byId[e.to].p, dx = b.x - a.x, dy = b.y - a.y, d = Math.sqrt(dx * dx + dy * dy) + 0.01, f = (d - 90) * 0.02;
        dx = dx / d * f; dy = dy / d * f;
        a.vx += dx; a.vy += dy; b.vx -= dx; b.vy -= dy;
      });
      g.nodes.forEach(function (n) {
        var p = n.p;
        p.x += p.vx * k * 10; p.y += p.vy * k * 10;
        p.vx *= 0.6; p.vy *= 0.6;
      });
      // the body in focus is drawn to the centre, and the rest settle round it
      var fp = graphView.focus && g.byId[graphView.focus] && g.byId[graphView.focus].p;
      if (fp) { fp.x *= 0.7; fp.y *= 0.7; fp.vx = 0; fp.vy = 0; }
    }
    function size() {
      var w = canvas.clientWidth || 600, h = canvas.clientHeight || 480, dpr = window.devicePixelRatio || 1;
      if (canvas.width !== Math.round(w * dpr) || canvas.height !== Math.round(h * dpr)) { canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr); }
      return { w: w, h: h, dpr: dpr };
    }
    // the farthest body from the centre sets the scale, so the whole
    // diagram fits the canvas at zoom 1 on any screen
    function scaleOf(s) {
      var R = 60;
      g.nodes.forEach(function (n) { var d = Math.sqrt(n.p.x * n.p.x + n.p.y * n.p.y); if (d > R) R = d; });
      return graphView.zoom * Math.min(s.w, s.h) * 0.45 / R;
    }
    function project(p, s, scale) { return { x: s.w / 2 + graphView.px + p.x * scale, y: s.h / 2 + graphView.py + p.y * scale }; }
    // a label with a halo of the canvas's own colour, readable over lines,
    // put at the first of its places that no label drawn before covers; a
    // label with no free place is left out, unless it must be drawn
    var boxes = [], room = { w: 0, h: 0 };
    function label(text, spots, font, color, c, must) {
      ctx.font = font;
      var w = ctx.measureText(text).width, h = 14, at = null;
      for (var i = 0; i < spots.length && !at; i++) {
        var x = spots[i][0], y = spots[i][1], free = x >= 2 && x + w <= room.w - 2 && y - h >= 0 && y + 3 <= room.h;
        for (var j = 0; j < boxes.length && free; j++) {
          var b = boxes[j];
          if (x < b[0] + b[2] && x + w > b[0] && y - h + 3 < b[1] + b[3] && y + 3 > b[1]) free = false;
        }
        if (free) at = spots[i];
      }
      if (!at) { if (!must) return; at = spots[0]; }
      boxes.push([at[0], at[1] - h + 3, w, h]);
      ctx.lineJoin = 'round'; ctx.lineWidth = 3.5; ctx.strokeStyle = c.card; ctx.strokeText(text, at[0], at[1]);
      ctx.fillStyle = color; ctx.fillText(text, at[0], at[1]);
    }
    function draw() {
      var s = size(), scale = scaleOf(s), c = palette();
      ctx.setTransform(s.dpr, 0, 0, s.dpr, 0, 0);
      ctx.clearRect(0, 0, s.w, s.h);
      proj = g.nodes.map(function (n) { return project(n.p, s, scale); });
      var focus = graphView.focus, pickedEdge = graphView.picked && graphView.picked.attr ? graphView.picked : null;
      var near = Object.create(null);
      if (focus) g.edges.forEach(function (e) { if (e.from === focus) near[e.to] = true; if (e.to === focus) near[e.from] = true; });
      // a line's words are drawn where they fit: every line of a small
      // diagram, the lines at the body in focus when there are few, and
      // all of them close up
      var close = graphView.zoom >= 1.8, words = [], lit0 = 0;
      g.edges.forEach(function (e) { if (e.from === focus || e.to === focus) lit0 += 1; });
      var sayAll = g.edges.length <= 40, sayLit = lit0 <= 12;
      g.edges.forEach(function (e) {
        var a = proj[at[e.from]], b = proj[at[e.to]];
        var lit = pickedEdge === e || e.from === focus || e.to === focus;
        ctx.globalAlpha = lit ? 0.9 : (focus ? 0.2 : 0.4);
        ctx.strokeStyle = lit ? c.ink : c.muted;
        ctx.lineWidth = lit ? 1.6 : 1;
        ctx.beginPath(); ctx.moveTo(a.x, a.y); ctx.lineTo(b.x, b.y); ctx.stroke();
        if (close || sayAll || pickedEdge === e || (lit && sayLit)) words.push([edgeWord(e.attr), 0, 0, lit, e]);
      });
      ctx.globalAlpha = 1;
      g.nodes.forEach(function (n, i) {
        var p = proj[i], ev = !!EVENT_KINDS[n.kind], r = (ev ? 4 : 6 + Math.min(n.degree, 10) * 0.4) * Math.min(1.6, Math.sqrt(graphView.zoom)) + (n.id === focus ? 3 : 0);
        ctx.globalAlpha = focus && n.id !== focus && !near[n.id] ? 0.35 : 1;
        ctx.fillStyle = n.closed ? c.muted : (KIND_COLORS[n.kind] || c.muted);
        ctx.beginPath(); ctx.arc(p.x, p.y, r, 0, Math.PI * 2); ctx.fill();
        if (n.id === focus || (graphView.picked && graphView.picked.id === n.id)) { ctx.lineWidth = 2.5; ctx.strokeStyle = c.ink; ctx.stroke(); }
        n.r = r;
      });
      ctx.globalAlpha = 1;
      boxes = []; room = { w: s.w, h: s.h };
      // names first, the body in focus before the rest, then the lines'
      // words in the room that is left
      var nearCount = Object.keys(near).length, named = [];
      g.nodes.forEach(function (n, i) {
        var ev = !!EVENT_KINDS[n.kind];
        // people, places, things and orgs are few, and always named where
        // there is room; an event only near the focus or close up
        if (n.id === focus || !ev || (near[n.id] && nearCount <= 25) || graphView.zoom >= 2.2) named.push(i);
      });
      named.sort(function (i, j) { return (g.nodes[j].id === focus) - (g.nodes[i].id === focus); });
      named.forEach(function (i) {
        var n = g.nodes[i], p = proj[i], t = n.name.length > 28 ? n.name.slice(0, 27) + '\u2026' : n.name, font = (n.id === focus ? 'bold ' : '') + '12px system-ui';
        ctx.font = font;
        var w = ctx.measureText(t).width;
        label(t, [[p.x + n.r + 3, p.y + 4], [p.x - n.r - 3 - w, p.y + 4], [p.x - w / 2, p.y - n.r - 4], [p.x - w / 2, p.y + n.r + 13]],
          font, focus && n.id !== focus && !near[n.id] ? c.muted : c.ink, c, n.id === focus);
      });
      words.forEach(function (wd) {
        var e = wd[4], a = proj[at[e.from]], b = proj[at[e.to]], dx = b.x - a.x, dy = b.y - a.y, d = Math.hypot(dx, dy) || 1, nx = -dy / d * 12, ny = dx / d * 12;
        ctx.font = '11px system-ui';
        var w = ctx.measureText(wd[0]).width, spots = [];
        [0.5, 0.35, 0.65].forEach(function (t) {
          var mx = a.x + dx * t - w / 2, my = a.y + dy * t + 4;
          spots.push([mx, my], [mx + nx, my + ny], [mx - nx, my - ny]);
        });
        label(wd[0], spots, '11px system-ui', wd[3] ? c.ink : c.muted, c, pickedEdge === e);
      });
    }
    // a frame is drawn while the layout settles or a hand is on it, and
    // twice after anything else moved it; then it rests
    function wake() { frames = 2; if (!graphTimer) graphTimer = requestAnimationFrame(loop); }
    function loop() {
      graphTimer = null;
      var settling = steps < hot;
      step();
      draw();
      if (frames > 0) frames -= 1;
      if (settling || graphView.touching || frames > 0) graphTimer = requestAnimationFrame(loop);
    }
    // a finger is wider than a cursor, so a touch reaches farther
    function hit(x, y) {
      var best = null, bd = touchy ? 24 : 12;
      g.nodes.forEach(function (n, i) { var p = proj[i], d = Math.hypot(p.x - x, p.y - y); if (d < bd) { bd = d; best = n; } });
      if (best) return best;
      var be = null, ed = touchy ? 14 : 8;
      g.edges.forEach(function (e) {
        var a = proj[at[e.from]], b = proj[at[e.to]];
        var l2 = (b.x - a.x) * (b.x - a.x) + (b.y - a.y) * (b.y - a.y); if (!l2) return;
        var t = Math.max(0, Math.min(1, ((x - a.x) * (b.x - a.x) + (y - a.y) * (b.y - a.y)) / l2));
        var d = Math.hypot(a.x + t * (b.x - a.x) - x, a.y + t * (b.y - a.y) - y);
        if (d < ed) { ed = d; be = e; }
      });
      return be;
    }
    // a body picked is centred on, when it is on the diagram; a line
    // picked is only lit
    function pick(what) {
      graphView.picked = what;
      if (what && !what.attr && at[what.id] !== undefined && graphView.focus !== what.id) {
        graphView.focus = what.id; graphView.px = 0; graphView.py = 0;
        steps = Math.min(steps, hot / 2);
      }
      if (!what) pane.innerHTML = emptyPane();
      else pane.innerHTML = what.attr ? edgePane(what, g) : nodePane(full.byId[what.id] || what, full);
      wake();
    }
    // pointer events carry mouse, pen and touch alike: one pointer moves
    // the diagram, two pinch it about their midpoint, a touch that did
    // not move picks
    var pts = Object.create(null), pinch = null;
    function pos(ev) { var r = canvas.getBoundingClientRect(); return { x: ev.clientX - r.left, y: ev.clientY - r.top }; }
    function held() { return Object.keys(pts).map(function (k) { return pts[k]; }); }
    function spread(t) { return Math.hypot(t[0].x - t[1].x, t[0].y - t[1].y) || 1; }
    function mid(t) { return { x: (t[0].x + t[1].x) / 2, y: (t[0].y + t[1].y) / 2 }; }
    // zoom about a point on the canvas: what is under it stays under it
    function zoomAbout(z, x, y, z0, px0, py0) {
      z = Math.max(0.3, Math.min(8, z));
      var w = canvas.clientWidth || 600, h = canvas.clientHeight || 480;
      var ax = x - w / 2 - px0, ay = y - h / 2 - py0;
      graphView.px = px0 + ax - ax * z / z0; graphView.py = py0 + ay - ay * z / z0;
      graphView.zoom = z;
    }
    canvas.onpointerdown = function (ev) {
      touchy = ev.pointerType !== 'mouse';
      try { canvas.setPointerCapture(ev.pointerId); } catch (e) { /* a pointer the page did not see start */ }
      pts[ev.pointerId] = pos(ev);
      var t = held();
      graphView.touching = t.length;
      if (t.length === 1) { drag = t[0]; moved = false; }
      else { pinch = { d: spread(t), zoom: graphView.zoom, mid: mid(t), px: graphView.px, py: graphView.py }; drag = null; moved = true; }
      wake();
    };
    canvas.onpointermove = function (ev) {
      if (!pts[ev.pointerId]) return;
      var p = pos(ev);
      pts[ev.pointerId] = p;
      var t = held();
      if (pinch && t.length >= 2) {
        var m = mid(t);
        zoomAbout(pinch.zoom * spread(t) / pinch.d, pinch.mid.x, pinch.mid.y, pinch.zoom, pinch.px, pinch.py);
        graphView.px += m.x - pinch.mid.x; graphView.py += m.y - pinch.mid.y;
      } else if (drag) {
        var dx = p.x - drag.x, dy = p.y - drag.y;
        if (Math.abs(dx) + Math.abs(dy) > (touchy ? 8 : 3)) moved = true;
        if (moved) { graphView.px += dx; graphView.py += dy; }
        drag = p;
      }
      wake();
    };
    function lift(ev) {
      var p = pts[ev.pointerId];
      if (!p) return;
      delete pts[ev.pointerId];
      var t = held();
      graphView.touching = t.length;
      if (t.length < 2) pinch = null;
      if (!t.length) { if (ev.type === 'pointerup' && drag && !moved) pick(hit(p.x, p.y)); drag = null; }
      else drag = t[0];
      wake();
    }
    canvas.onpointerup = canvas.onpointercancel = lift;
    canvas.onwheel = function (ev) { ev.preventDefault(); var p = pos(ev); zoomAbout(graphView.zoom * (ev.deltaY > 0 ? 0.9 : 1.1), p.x, p.y, graphView.zoom, graphView.px, graphView.py); wake(); };
    canvas.ondblclick = function () { graphView.zoom = 1; graphView.px = 0; graphView.py = 0; wake(); };
    pane.onclick = function (ev) {
      var a = ev.target.closest('[data-pick]'); if (!a) return;
      ev.preventDefault(); var n = full.byId[a.dataset.pick]; if (n) pick(n);
    };
    find.oninput = function () {
      var q = find.value.trim().toLowerCase(); if (!q) return;
      var n = full.all.filter(function (n) { return n.name.toLowerCase().indexOf(q) >= 0 || n.id.indexOf(q) >= 0; })[0];
      if (n) pick(n);
    };
    pastBox.onchange = function () { graphView.past = pastBox.checked; unmountGraph(); mountGraph(graphState); };
    eventsBox.onchange = function () { graphView.events = eventsBox.checked; unmountGraph(); mountGraph(graphState); };
    unmountGraph();
    if (graphView.picked) { var again = graphView.picked.attr ? null : full.byId[graphView.picked.id]; pick(again || null); }
    else pick(null);
    wake();
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

  // drawn: the view the page shows, so a refresh can tell a redraw of
  // it from a move to another. seen: each view's last answer, so a view
  // visited before draws at once while its fresh answer comes (each
  // request costs the owner's ship seconds). Settings and keys are never
  // drawn from it: their forms save whole documents, and a stale one
  // saved would undo a newer change.
  var refreshing = false, again = false, drawn = '', seen = Object.create(null), lastState = null;
  function viewNow() {
    var r = route(location.hash);
    var name = r.name === 'body' || r.name === 'inbox' || r.name === 'settings' || r.name === 'keys' ? r.name : 'bodies';
    return { r: r, name: name, here: name + ' ' + (r.id || ''), cached: name !== 'settings' && name !== 'keys' };
  }
  // one view drawn from its answer, through show, which may hold it
  function drawView(v, d, show) {
    if (v.name !== 'bodies') unmountGraph();
    if (v.name === 'body') return show(body(d[0], d[1]));
    if (v.name === 'inbox') return show(inbox(openActions(d), d));
    if (v.name === 'settings') {
      var l = d.chat_lists || {};
      var drew = show(settings(d.schema, d.policy, d.generator, d.generator_last, d.reconcile_last, d.telegram, d.telegram_last, d.exec_last, d.chat, d.chat_last, l.dms, l.channels, d.calendar_last, d.mail, d.mail_last, d.brief_last, d.read, d.read_last, d.reasons, d.tally));
      if (drew) fillCalendars();
      return drew;
    }
    if (v.name === 'keys') return show(keys(d[0], d[1], minted));
    // the graph drawn already takes the new state in place: a redraw
    // would drop the hand on it and the find box's words
    if (drawn === v.here && document.getElementById('graph')) {
      var count = view.querySelector('h1 .muted'), tidy = document.getElementById('tidy');
      if (count) count.textContent = String((d.bodies || []).length);
      if (tidy) tidy.outerHTML = tidyCard(d, tidy.open, tidyGone);
      mountGraph(d);
      return true;
    }
    if (show(bodies(d, tidyGone))) mountGraph(d);
    return true;
  }
  // a move to a view seen before draws it from what was seen, at once
  function drawSeen(v) {
    if (v.here === drawn || !v.cached || !seen[v.here]) return;
    drawView(v, seen[v.here], function (html) { view.innerHTML = html; drawn = v.here; return true; });
  }
  function refresh(force) {
    var v = viewNow();
    if (v.name !== 'keys') minted = null;
    // an answer still out for another view does not hold a move
    if (refreshing) { again = true; drawSeen(v); return; }
    if (editing() && !force) { say('not refreshed: a form holds unsaved changes'); return; }
    refreshing = true;
    // the fetches take seconds on a busy ship, and the owner may start
    // typing meanwhile: what was typed on this same view outlives the
    // refresh (a schema edit was lost so, 2026-09-25)
    var mark = edits, held = false;
    function show(html) {
      if ((edits !== mark || graphView.touching) && v.here === drawn) { held = true; say('not refreshed: a form holds unsaved changes'); return false; }
      view.innerHTML = html; drawn = v.here; return true;
    }
    // one request a view: the state carries the open actions, /settings
    // every document the settings page shows, and a body's page takes
    // its names from the last state read when there is one
    function fetchView() {
      if (v.name === 'body') return Promise.all([api('/body/' + seg(v.r.id)), lastState ? Promise.resolve(lastState) : api('/state')]);
      if (v.name === 'settings') return api('/settings');
      if (v.name === 'keys') return Promise.all([api('/clients'), api('/schema')]);
      // the rev drawn already: the ship answers "same" when nothing moved
      // since, and the state already held stands
      var had = lastState;
      var rev = had && typeof had.rev === 'number' ? '?rev=' + had.rev : '';
      return api('/state' + rev).then(function (s) { return s && s.same ? had : s; });
    }
    drawSeen(v);
    var before = lastState && lastState.rev;
    var p = fetchView().then(function (d) {
      // the very answer drawn already needs no drawing again; asked before
      // the answer is kept below, or every answer would look drawn
      var again = seen[v.here] === d && drawn === v.here;
      var s = v.name === 'body' ? d[1] : (v.name === 'bodies' || v.name === 'inbox') ? d : null;
      if (awaitMove > 0 && s) {
        var still = awaitGone ? (s.bodies || []).some(function (x) { return awaitGone.indexOf(x.id) >= 0; }) : s.rev === before;
        if (still) { awaitMove -= 1; if (awaitMove > 0) setTimeout(function () { refresh(!dirty); }, 1000); }
        else { awaitMove = 0; awaitGone = null; }
      }
      if (s && s !== lastState) {
        lastState = s;
        if (typeof s.rev === 'number') lastRev = String(s.rev);
        var n = (s.actions || []).filter(function (a) { return a.status === 'proposed'; }).length;
        countEl.textContent = n ? String(n) : '';
        // the state answers the bodies view and the inbox alike
        seen['bodies '] = s; seen['inbox '] = s;
      }
      seen[v.here] = d;
      // the owner moved on while it was out: kept, not drawn over the
      // view they are on
      if (viewNow().here !== v.here || again) { if (!held) say(''); return; }
      drawView(v, d, show);
      if (!held) say('');
    }).catch(function (e) { say(String(e.message || e), true); });
    p.then(function () { refreshing = false; if (again) { again = false; refresh(); } });
  }
  // a tidy move shows at once: its button says what is under way, and once
  // the ship has taken it the row is struck through, before the refresh
  // that follows comes back (each costs the ship seconds)
  function working(b, what) { b.disabled = true; b.dataset.was = b.textContent; b.textContent = what + '\u2026'; say(what + '\u2026'); }
  function settled(b, what) {
    var li = b.closest('li');
    if (li) { li.classList.add('done'); b.remove(); li.insertAdjacentHTML('beforeend', ' <span class="muted">' + what + '</span>'); }
    say(what);
  }
  function unsettled(b) { b.disabled = false; if (b.dataset.was) b.textContent = b.dataset.was; }
  // the calendar's own lists for the executor card's two choices, from
  // the calendar's route on this same ship; a calendar not installed
  // leaves the default alone
  function fillCalendars() {
    var picks = ['todo-cal', 'event-cal'].map(function (id) { return document.getElementById(id); }).filter(Boolean);
    if (!picks.length) return;
    fetch('/apps/calendar/calendars.json', { credentials: 'include' }).then(function (r) { return r.ok ? r.json() : []; }).then(function (cals) {
      picks.forEach(function (sel) {
        (Array.isArray(cals) ? cals : []).forEach(function (c) {
          if (!c || !c.id || c.readonly) return;
          var o = document.createElement('option');
          o.value = c.id;
          o.textContent = (c.name || c.id) + (c.kind && c.kind !== 'local' ? ' (' + c.kind + ')' : '');
          sel.appendChild(o);
        });
        sel.value = sel.dataset.now || '';
        if (sel.value !== (sel.dataset.now || '')) {
          var gone = document.createElement('option');
          gone.value = sel.dataset.now; gone.textContent = sel.dataset.now + ' (not on the calendar)';
          sel.appendChild(gone); sel.value = sel.dataset.now;
        }
      });
    }).catch(function () { /* no calendar: the default stands */ });
  }
  // the inbox's actions, newest first, as the actions route answered them
  function openActions(state) {
    return (state.actions || []).slice().sort(function (a, b) { return String(b.proposed || '').localeCompare(String(a.proposed || '')); });
  }

  // a write answers before the writer applies, so the refetch waits
  // after a move: a note half-typed under another action is kept, so the
  // refresh waits for it rather than wiping it
  function typedNote() { return Array.prototype.some.call(view.querySelectorAll('[data-refine-text]'), function (i) { return !!i.value.trim(); }); }
  // after the owner's own move the refresh looks again each second until
  // the move shows: the writer applies it a while after the answer, and
  // the beacon's news can lag a minute. A merge or a delete shows when
  // the body is gone from the state (the rev also moves for the ship's
  // other writes meanwhile); any other move when the rev moves.
  var awaitMove = 0, awaitGone = null, tidyGone = Object.create(null);
  function later(gone) { dirty = typedNote(); awaitMove = gone ? 20 : 10; awaitGone = gone || null; setTimeout(function () { refresh(!dirty); }, 300); }

  view.addEventListener('click', function (ev) {
    var b = ev.target.closest('button');
    if (!b) return;
    if (b.dataset.merge) {
      if (!confirm('Merge ' + b.dataset.merge + ' into ' + b.dataset.into + '? Its facts move, what pointed at it points at ' + b.dataset.into + ', and ' + b.dataset.merge + ' goes.')) return;
      working(b, 'merging');
      post('/merge', { from: b.dataset.merge, into: b.dataset.into }).then(function () { tidyGone[b.dataset.merge] = true; settled(b, 'merged'); later([b.dataset.merge]); }).catch(function (e) { unsettled(b); oops(e); });
    } else if (b.dataset.deleteBody) {
      if (!confirm('Delete ' + (b.dataset.name || b.dataset.deleteBody) + ' and everything the ship knows of it?')) return;
      working(b, 'deleting');
      api('/body/' + b.dataset.deleteBody.split('/').map(seg).join('/'), { method: 'DELETE' }).then(function () { tidyGone[b.dataset.deleteBody] = true; settled(b, 'deleted'); later([b.dataset.deleteBody]); }).catch(function (e) { unsettled(b); oops(e); });
    } else if (b.dataset.unalias) {
      if (!confirm('Take "' + b.dataset.unalias + '" off ' + b.dataset.id + '? The readers no longer know it by that name.')) return;
      working(b, 'removing');
      post('/unalias', { id: b.dataset.id, alias: b.dataset.unalias }).then(function () { var s = b.closest('.alias'); if (s) s.remove(); say('alias removed'); later(); }).catch(function (e) { unsettled(b); oops(e); });
    } else if (b.dataset.prefer) {
      var list = document.getElementById('pref-list');
      if (list) { list.value = list.value.replace(/\s+$/, '') + (list.value.trim() ? '\n' : '') + b.dataset.prefer; dirty = true; edits += 1; }
      var li = b.closest('li'); if (li) li.remove();
      say('added below: save to keep it');
    } else if (b.dataset.savePrefs) {
      var style = (document.getElementById('pref-style') || {}).value || '';
      var lines = ((document.getElementById('pref-list') || {}).value || '').split('\n').map(function (t) { return t.trim(); }).filter(Boolean);
      api('/schema').then(function (sch) {
        sch = sch && typeof sch === 'object' ? sch : {};
        sch.style = style.trim();
        sch.preferences = lines;
        return post('/schema', sch, 'PUT');
      }).then(function () { dirty = false; say('style and preferences saved'); refresh(true); }).catch(oops);
    } else if (b.dataset.saveCals) {
      var todoCal = (document.getElementById('todo-cal') || {}).value || '', eventCal = (document.getElementById('event-cal') || {}).value || '';
      api('/policy').then(function (pol) {
        pol = pol && typeof pol === 'object' ? pol : {};
        pol.todo_calendar = todoCal;
        pol.event_calendar = eventCal;
        return post('/policy', pol, 'PUT');
      }).then(function () { dirty = false; say('saved: new todos and events go there'); refresh(true); }).catch(oops);
    } else if (b.dataset.retract) {
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
  // every edit counted: a refresh whose fetches were out while one was
  // made does not draw over it
  var edits = 0;
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
    if (el && (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT')) { dirty = true; edits += 1; }
  });
  view.addEventListener('change', function (e) {
    if (e.target && e.target.tagName === 'SELECT') { dirty = true; edits += 1; }
  });
  function editing() {
    if (dirty || graphView.touching) return true;
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
