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
    // a twin: the same body on another ship (version 89)
    if (typeof v === 'object' && !Array.isArray(v) && typeof v.ship === 'string' && typeof v.id === 'string') return esc(v.id) + ' on ' + esc(v.ship);
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
  // free text, such as an action's title, escaped, each id in it the ship
  // has a name for read as that name
  function namedText(t, byId) {
    return esc(t).replace(/\b[a-z]+\/[a-z0-9][a-z0-9.-]*/g, function (id) {
      var known = byId && byId[id];
      return known && known.name ? esc(known.name) : id;
    });
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
  // hidden: the kinds the owner turned off (version 68), each a
  // checkbox above the diagram. A hidden event kind (situation,
  // activity) folds: two bodies that share one are a line saying how
  // many, beside what else relates them ("son · 25 events"). Any other
  // hidden kind is left off with its lines. The default hides only
  // activities: an open situation is what the ship works on, and from
  // 58 to 67 the default view hid every one. false is that default and
  // true or nothing hides nothing, as the tests and the pane ask
  var DEFAULT_HIDDEN = { activity: true };
  function graphOf(state, showPast, hidden) {
    if (hidden === false) hidden = DEFAULT_HIDDEN;
    if (!hidden || hidden === true) hidden = {};
    var FOLDED_KINDS = {};
    Object.keys(EVENT_KINDS).forEach(function (k) { if (hidden[k]) FOLDED_KINDS[k] = true; });
    var folding = Object.keys(FOLDED_KINDS).length > 0;
    var nodes = [], byId = Object.create(null), edges = [], seen = Object.create(null);
    (state.bodies || []).forEach(function (b) {
      var st = b.attrs && b.attrs.status, closed = !!(st && !Array.isArray(st) && (st.value === 'closed' || st.value === 'cancelled'));
      if (b.kind === 'situation' && closed && !showPast) return;
      if (hidden[b.kind] && !EVENT_KINDS[b.kind]) return;
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
    if (folding) {
      var pairs = Object.create(null), order = [];
      var line = function (from, to) {
        var key = from < to ? from + '|' + to : to + '|' + from;
        if (!pairs[key]) { pairs[key] = { from: from, to: to, words: [], shared: 0, at: '' }; order.push(key); }
        return pairs[key];
      };
      edges.forEach(function (e) {
        if (FOLDED_KINDS[byId[e.from].kind] || FOLDED_KINDS[byId[e.to].kind]) return;
        var l = line(e.from, e.to);
        if (l.words.indexOf(e.attr) < 0) l.words.push(e.attr);
      });
      nodes.forEach(function (ev) {
        if (!FOLDED_KINDS[ev.kind]) return;
        var with_ = [];
        edges.forEach(function (e) {
          var other = e.from === ev.id ? e.to : e.to === ev.id ? e.from : null;
          if (other && !FOLDED_KINDS[byId[other].kind] && with_.indexOf(other) < 0) with_.push(other);
        });
        for (var i = 0; i < with_.length; i++) for (var j = i + 1; j < with_.length; j++) line(with_[i], with_[j]).shared += 1;
      });
      nodes.forEach(function (n) { n.degree = 0; });
      edges = order.map(function (key) {
        var l = pairs[key];
        // involved is what participants says from the other end: one word
        var words = l.words.length > 1 ? l.words.filter(function (w) { return w !== 'involved'; }) : l.words.slice();
        if (l.shared) words.push(l.shared + (l.shared === 1 ? ' event' : ' events'));
        byId[l.from].degree += 1; byId[l.to].degree += 1;
        return { from: l.from, to: l.to, attr: words.join(' \u00b7 '), at: l.at };
      });
      nodes = nodes.filter(function (n) { return !FOLDED_KINDS[n.kind]; });
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
      Object.keys(KIND_COLORS).map(function (k) {
        return '<label class="box"><input type="checkbox" data-kind="' + k + '"' + (DEFAULT_HIDDEN[k] ? '' : ' checked') + '> <i class="dot" style="background:' + KIND_COLORS[k] + '"></i>' + esc(k) + '</label>';
      }).join('') +
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
  // a row another ship sent says whose it is: the person carrying that
  // ship, marked as theirs (version 93)
  function byWho(by, state) {
    by = String(by || '');
    if (by.charAt(0) !== '~') return esc(by);
    var who = ((state && state.bodies) || []).filter(function (b) { return b.ship === by; })[0];
    return '<span class="peer" title="from ' + esc(by) + '">' + esc(who ? who.name || who.id : by) + '</span>';
  }
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
    out += instructBox(v.id, '', 'Tell the ship what is wrong or what to do about ' + (v.name || v.id));
    var attrs = Object.keys(v.attrs || {}).sort();
    out += '<div class="card"><h2>Now</h2>';
    if (!attrs.length) out += '<p class="muted">No current attributes.</p>';
    else {
      out += thead(['attribute', 'value', 'since', 'by', 'source']);
      attrs.forEach(function (a) {
        var rows = v.attrs[a];
        (Array.isArray(rows) ? rows : [rows]).forEach(function (r) {
          if (!r) return;
          out += '<tr>' + cell('attribute', esc(a)) + cell('value', fmtValue(r.value) + notTrue(v.id, a, r.value)) + cell('since', fmtTime(r.at)) +
            cell('by', byWho(r.by, state)) + cell('source', source(r.source)) + '</tr>';
        });
      });
      out += '</tbody></table>';
    }
    out += '</div>';
    if (v.involved && v.involved.length) out += '<div class="card"><h2>Involved in</h2>' + situationCards(v.involved, state) + '</div>';
    out += '<div class="card" id="body-sharing" data-id="' + esc(v.id) + '"><h2>Sharing</h2><p class="muted">Loading who this is shared with.</p></div>';
    if (v.actions && v.actions.length) {
      out += '<div class="card"><h2>Open actions</h2><ul class="actions">';
      var named = index(state);
      v.actions.forEach(function (a) { out += '<li>' + badge(a.status) + ' ' + namedText(a.title, named) + ' <span class="muted">' + esc(a.kind) + '</span></li>'; });
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

  // a value struck as wrong goes from every source and the writer
  // refuses it after; a correction names a string or a ref, nothing else
  function notTrue(id, attr, value) {
    var named = typeof value === 'string' ? value : (value && typeof value === 'object' && typeof value.ref === 'string' ? value.ref : '');
    if (!named) return '';
    return ' <button class="small" data-correct="' + esc(id) + '" data-attr="' + esc(attr) + '" data-value="' + esc(named) + '" aria-label="not true">not true</button>';
  }
  // the owner's own words, which the ship turns into actions: filed as
  // proposals, or done at once. On a body it is about that body; under
  // an action it answers that action.
  // the ship's last reply to each box, kept past the redraw its actions cause
  var replied = Object.create(null);
  function instructBox(about, action, hint) {
    var k = esc(about + '|' + action);
    return '<div class="instruct"><textarea class="short" rows="2" data-instruct-text="' + k + '" placeholder="' + esc(hint) + '" aria-label="an instruction"></textarea>' +
      '<p><button data-instruct="' + k + '">do it</button> <button data-instruct="' + k + '" data-propose="1">propose</button> <span class="muted" data-instruct-note="' + k + '">' + esc(replied[about + '|' + action] || '') + '</span></p></div>';
  }

  var MOVES = { proposed: ['approved', 'dismissed'], approved: ['done', 'failed', 'dismissed'], claimed: ['dismissed'] };
  var ASSIGNABLE = ['task', 'note'];
  // whose an action is: for someone else, or sent from another ship
  function forWhom(a, state) {
    var who = a && a.payload && a.payload.assignee && a.payload.assignee.ref;
    var from = a && a.payload && a.payload.twin;
    var out = '';
    if (from) out += ' <span class="peer">from ' + esc(nameOfShip(from.ship, state)) + ', for you</span>';
    else if (who && who !== 'person/me') out += ' <span class="peer">for ' + esc(nameOfBody(who, state)) + '</span>' +
      (a.status === 'approved' ? ' <span class="muted">sent to them; open here until they finish it</span>' : '');
    return out;
  }
  function assignBox(a, state) {
    var cur = (a.payload && a.payload.assignee && a.payload.assignee.ref) || '';
    var people = ((state && state.bodies) || []).filter(function (b) { return b.kind === 'person' && b.id !== 'person/me'; });
    var shown = people.map(function (p) { return Object.assign({}, p, { name: (p.name || p.id) + (p.ship ? ' (their orrery)' : '') }); });
    return '<p class="assign"><label class="field">who does it ' + personPicker('assign-who', shown, { blank: 'me', current: cur }) +
      '</label> <button class="small" data-assign="' + esc(a.id) + '">assign</button></p>';
  }
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
    var keys = Object.keys(p || {}).filter(function (k) { return k !== 'why' && k !== 'twin'; }).sort();
    if (!keys.length) return '';
    return '<div class="payload">' + keys.map(function (k) {
      return '<span class="muted">' + esc(k) + '</span> ' + namedValue(p[k], byId);
    }).join(' &middot; ') + '</div>';
  }
  // a value as a person reads it: a body it names by that body's name (its
  // id when the ship has no name for it), linked; anything else as it is
  function namedValue(v, byId) {
    var id = typeof v === 'string' ? v : (v && typeof v === 'object' && typeof v.ref === 'string' ? v.ref : '');
    if (id && /^[a-z0-9-]+\/[^\s]+$/.test(id) && (byId[id] || typeof v === 'object' || id.indexOf('person/') === 0)) return links([id], byId);
    return fmtValue(v);
  }
  function inbox(actions, state) {
    var out = '<h1>Inbox</h1>' + instructBox('', '', 'Tell the ship anything: "Dana was not in Barcelona", "Sam and Samuel are one person", "never propose calls"');
    if (!actions || !actions.length) return out + '<p class="muted">Nothing waiting.</p>';
    var byId = index(state);
    out += '<ul class="actions">';
    actions.forEach(function (a) {
      out += '<li class="card">' + badge(a.status) +
        (a.status === 'claimed' ? ' <span class="muted">claimed by ' + esc(claimant(a)) + '</span>' : '') +
        ' <strong>' + namedText(a.title, byId) + '</strong> <span class="muted">' + esc(a.kind) +
        ' &middot; proposed ' + fmtTime(a.proposed) + ' by ' + byWho(a.by, state) + (a.due ? ' &middot; due ' + fmtTime(a.due) : '') + '</span>' + forWhom(a, state) +
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
      } else if (a.status === 'proposed') {
        out += instructBox('', a.id, 'Answer it: "remove her", "she was never there"');
      }
      // who does it (version 95): someone with their own orrery gets it in
      // their Inbox once this is approved
      if (a.status === 'proposed' && ASSIGNABLE.indexOf(a.kind) >= 0 && !(a.payload && a.payload.twin)) out += assignBox(a, state);
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
      // the stops on a map, fetched by the ship from Mapbox as it is shown (version 73)
      if (last.map) out += '<p><img class="brief-map" alt="Today\'s stops on a map" src="' + API + '/brief/map?at=' + encodeURIComponent(last.at) + '"></p>';
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
  // the facts the owner struck, which the writer refuses and every
  // prompt is told of; undo lets the value be written again
  function correctionsCard(cs) {
    if (!cs || !cs.length) return '';
    return '<div class="card"><h2>Struck as wrong</h2><p class="muted">The writer refuses these and every prompt is told of them.</p><ul class="links">' +
      cs.map(function (c) {
        return '<li><a href="#body/' + esc(c.subject) + '">' + esc(c.subject) + '</a> ' + esc(c.attr) + ' = ' + esc(c.value) +
          (c.why ? ' <span class="muted">' + esc(c.why) + '</span>' : '') + ' <span class="muted">' + fmtTime(c.at) + '</span>' +
          ' <button class="small" data-uncorrect="' + esc(c.id) + '">undo</button></li>';
      }).join('') + '</ul></div>';
  }
  // the time-to-leave card (version 69): on or off, the Mapbox token
  // (never shown back), the lead and the minutes to park, when the phone
  // last said where the owner is (when, never where), and the last plan
  function travelCard(t, last) {
    t = t || {}; last = last || {};
    var out = '<div class="card"><h2>Time to leave</h2><div id="travel">' +
      '<p class="muted">The ship tells you when to leave for an appointment you go to, from where your phone last was, with Mapbox\'s live traffic. ' +
      'Your phone sends its position to the ship; the ship keeps only the latest and sends it to Mapbox with the appointment\'s address.</p>' +
      '<p><label class="box"><input type="checkbox" name="enabled"' + (t.enabled ? ' checked' : '') + '> on</label></p>' +
      '<p><label class="field">Mapbox token <input name="token" type="password" placeholder="' + (t.token_set ? 'a token is set; leave blank to keep it' : 'no token set') + '"></label></p>' +
      '<p><label class="field">minutes of warning <input name="lead_min" value="' + esc(t.lead_min != null ? t.lead_min : '') + '" placeholder="10"></label> ' +
      '<label class="field">minutes to park and walk in <input name="buffer_min" value="' + esc(t.buffer_min != null ? t.buffer_min : '') + '" placeholder="5"></label></p>' +
      '<p><button data-save-travel="1">save</button><button data-travel-wake="1">look now</button></p></div>' +
      '<p class="muted">' + (t.position_at ? 'Your phone last said where you are ' + fmtTime(t.position_at) + '.' : 'Your phone has not said where you are.') + '</p>';
    var n = last.next;
    if (n && n.name) {
      // why the drive is what it is, and what arrivals there taught (version 73)
      var usual = n.typical_minutes != null && n.minutes >= n.typical_minutes + 3 ? ' (' + n.typical_minutes + ' usual)' : '';
      out += '<p class="muted">Next: ' + esc(n.name) + ' at ' + fmtTime(n.starts) + ', ' + esc(String(n.minutes)) + ' min with traffic' + esc(usual) +
        (n.via ? ' via ' + esc(n.via) : '') + ', leave by ' + fmtTime(n.leave_by) + '.' +
        (n.learned_min ? ' Your arrivals there add ' + esc(String(n.learned_min)) + ' min to park.' : '') + '</p>';
      if (n.incident) out += '<p class="muted">On the way: ' + esc(n.incident) + '</p>';
    }
    (last.notes || []).forEach(function (x) { out += '<p class="muted">' + esc(x) + '</p>'; });
    return out + '</div>';
  }
  // the week (version 74): what the phone and the computer reported, the
  // baseline's progress, and the last Sunday review with a button to send one
  function weekCard(w) {
    w = w || {};
    var h = w.health || {}, k = w.work || {}, r = w.review || {};
    var out = '<div class="card"><h2>The week</h2><p class="muted">Your phone sends a day of health (steps, workouts, sleep) and your computer a day of work; ' +
      'the ship keeps sixty days, never as facts, and on Sunday at six it mails you the week: work, health, time with each child, and the week ahead.</p>';
    var days = w.healthDays || 0;
    out += '<p class="muted">' + (days ? 'Health: ' + days + ' day' + (days === 1 ? '' : 's') + ' kept' + (days < 14 ? '; the baseline needs 14' : '') + '.' : 'Health: nothing from your phone yet.') +
      (h.day ? ' Last, ' + esc(h.day) + ': ' + (h.steps != null ? esc(String(h.steps)) + ' steps' : 'no steps') + ', ' + (h.workouts || []).length + ' workout' + ((h.workouts || []).length === 1 ? '' : 's') + '.' : '') + '</p>';
    out += '<p class="muted">' + (k.day ? 'Work, ' + esc(k.day) + ': ' + Math.floor((k.active_minutes || 0) / 60) + ' h ' + ((k.active_minutes || 0) % 60) + ' min at the computer.' : 'Work: nothing from your computer yet.') + '</p>';
    // the day's nudges (version 75): three at most, none from nine at night to seven
    var sent = (w.nudge && w.nudge.sent) || [];
    out += '<p class="muted">Nudges ' + (w.nudge && w.nudge.day ? 'on ' + esc(w.nudge.day) + ': ' + sent.length + ' of 3' : 'today: none yet') +
      (sent.length ? '. Last: ' + esc(sent[sent.length - 1].title || '') + ' (' + fmtTime(sent[sent.length - 1].at) + ')' : '') + '.</p>';
    // your day (version 75): the times the nudges and the habit slots keep to
    var rh = w.rhythm || {};
    var fld = function (name, label, ph) { return '<label class="field">' + label + ' <input name="' + name + '" value="' + esc(rh[name] != null ? String(rh[name]) : '') + '" placeholder="' + ph + '"></label> '; };
    out += '<div id="rhythm"><p class="muted">Your day: times as HH:MM on your clock. Leave family time blank if you have none.</p>' +
      '<p>' + fld('quiet_from', 'quiet from', '21:00') + fld('quiet_to', 'to', '07:00') + '</p>' +
      '<p>' + fld('family_from', 'family time from', '') + fld('family_to', 'to', '') + '</p>' +
      '<p>' + fld('evening_from', 'habits in the evening from', '18:00') + fld('evening_to', 'to', '21:00') + '</p>' +
      '<p>' + fld('weekend_from', 'and weekend mornings from', '09:00') + fld('weekend_to', 'to', '12:00') + '</p>' +
      '<p>' + fld('per_window', 'habits a window', '2') + fld('young_age', 'children under', '0') + fld('young_share', 'get this share of your time, %', '100') + '</p>' +
      '<p><button data-save-rhythm="1">save your day</button></p></div>';
    // outdoors (version 76): the weather from the National Weather Service, and Parks on the Air parks near you
    var od = w.outdoors || {}, wl = w.weather || {}, pl = w.parks || {};
    out += '<div id="outdoors"><p class="muted">Outdoors: the weather for home (or your phone\'s last place) adds minutes to the time to leave in rain or storms, and the brief names the days an outing\'s weather comes ' +
      '(set wind-mph, rain-max, temp-f on the activity). ' + (wl.forecast_at ? 'Forecast ' + fmtTime(wl.forecast_at) + (wl.alerts ? ', ' + wl.alerts + ' alert' + (wl.alerts === 1 ? '' : 's') : '') + '.' : esc(wl.note || 'No forecast yet.')) +
      (pl.at ? ' Parks ' + fmtTime(pl.at) + ': ' + (pl.near || 0) + ' near, ' + (pl.added || 0) + ' new' + (pl.note ? ' (' + esc(pl.note) + ')' : '') + '.' : '') + '</p>' +
      '<p><label class="field"><input type="checkbox" name="weather"' + (od.weather !== false ? ' checked' : '') + '> weather</label> ' +
      '<label class="field"><input type="checkbox" name="pota"' + (od.pota ? ' checked' : '') + '> POTA parks</label> ' +
      '<label class="field">location <input name="pota_location" value="' + esc(od.pota_location || '') + '" placeholder="US-CO"></label> ' +
      '<label class="field">within, km <input name="pota_radius_km" value="' + esc(od.pota_radius_km != null ? String(od.pota_radius_km) : '') + '" placeholder="40"></label></p>' +
      '<p><button data-save-outdoors="1">save outdoors</button></p></div>';
    // place lookups (version 87): Brave Search fills in a place's address, phone, hours and website
    var sc = w.search || {}, sl = w.searchLast || {};
    out += '<div id="search"><p class="muted">Place lookups: Brave Search fills in what a place is missing (address, phone, hours, website), ten at most twice a day, never over your facts. ' +
      'Each lookup sends Brave the place\'s name and your home\'s area; never a person. ' + (sl.at ? 'Last ' + fmtTime(sl.at) + ': ' + (sl.looked || 0) + ' looked up, ' + (sl.filled || 0) + ' facts, ' + (sl.used || 0) + ' this month' + (sl.note ? ' (' + esc(sl.note) + ')' : '') + '.' : '') + '</p>' +
      '<p><label class="field"><input type="checkbox" name="enabled"' + (sc.enabled ? ' checked' : '') + '> on</label> ' +
      '<label class="field">Brave Search API key <input name="api_key" type="password" placeholder="' + (sc.api_key_set ? 'set; blank keeps it' : 'not set') + '"></label> ' +
      '<label class="field">a month at most <input name="monthly_cap" value="' + esc(sc.monthly_cap != null ? String(sc.monthly_cap) : '') + '" placeholder="500"></label></p>' +
      '<p><button data-save-search="1">save place lookups</button></p></div>';
    out += '<div class="card"><h2>Location</h2><p class="muted">Sharing where you are is on the <a href="#sharing">Sharing</a> page now.</p></div>';
    out += '<p><button data-review-wake="1">send the review now</button></p>';
    if (r.at) out += '<p class="muted">Last review ' + fmtTime(r.at) + (r.sent ? ', sent' : ', not sent') + '.</p><pre class="review">' + esc(r.text || '') + '</pre>';
    return out + '</div>';
  }
  function settings(schema, policy, generator, last, reconcile, telegram, telegramLast, execLast, chat, chatLast, dms, channels, calLast, mail, mailLast, briefLast, read, readLast, reasons, tally, corrections, travel, travelLast, week) {
    return '<h1>Settings</h1>' + prefsCard(schema, reasons) + correctionsCard(corrections) + generatorCard(generator, last) + qualityCard(tally) + reconcileCard(reconcile) + executorCard(execLast, calLast, policy) + travelCard(travel, travelLast) + weekCard(week) + telegramCard(telegram, telegramLast) + chatCard(chat, chatLast, dms, channels) + mailCard(mail, mailLast) + readCard(read, readLast) + briefCard(briefLast) +
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

  // the parts of the owner's life (version 84): each sphere, what is
  // filed under it and who filed it, and the filings a model made that
  // wait for the owner; whatever is under no sphere is home's
  function spheres(state) {
    state = state || {};
    var all = state.bodies || [], byId = {};
    all.forEach(function (b) { byId[b.id] = b; });
    var rowsOf = function (b) { var v = b.attrs && b.attrs.sphere; return !v ? [] : Array.isArray(v) ? v : [v]; };
    var refOf = function (r) { return r && r.value && typeof r.value === 'object' ? String(r.value.ref || '') : ''; };
    var list = all.filter(function (b) { return b.kind === 'sphere'; });
    if (!byId['sphere/home']) list.unshift({ id: 'sphere/home', kind: 'sphere', name: 'Home', attrs: {} });
    list.sort(function (a, b) { return a.id === 'sphere/home' ? -1 : b.id === 'sphere/home' ? 1 : String(a.name).localeCompare(String(b.name)); });
    var waiting = (state.actions || []).filter(function (a) { return a.kind === 'fact' && a.status === 'proposed' && a.payload && a.payload.attr === 'sphere'; });
    var unfiled = all.filter(function (b) { return b.kind !== 'sphere' && b.kind !== 'note' && b.id !== 'person/me' && !rowsOf(b).length; }).length;
    var out = '<h1>Spheres</h1><p class="muted">The parts of your life. Whatever is filed under none is home\'s. ' +
      'What a model files under a sphere waits for you in the Inbox until you have confirmed three there.</p>' +
      '<div id="pairing-card"></div>';
    list.forEach(function (s) {
      var members = all.filter(function (b) { return rowsOf(b).some(function (r) { return refOf(r) === s.id; }); });
      var asks = waiting.filter(function (a) { return a.payload.value && a.payload.value.ref === s.id; });
      var summary = s.attrs && s.attrs.summary && s.attrs.summary.value;
      out += '<div class="card"><h2>' + esc(s.name || s.id) + '</h2>' + (summary ? '<p>' + esc(summary) + '</p>' : '');
      if (!members.length) out += '<p class="muted">' + (s.id === 'sphere/home' ? 'Nothing filed here by name.' : 'Nothing filed here yet.') + '</p>';
      else {
        out += '<ul>' + members.map(function (b) {
          var r = rowsOf(b).filter(function (x) { return refOf(x) === s.id; })[0] || {};
          return '<li><a href="#body/' + esc(b.id) + '">' + esc(b.name || b.id) + '</a> <span class="muted">' + esc(b.kind) + ' &middot; filed by ' + esc(r.by || '') + '</span></li>';
        }).join('') + '</ul>';
      }
      if (s.id === 'sphere/home' && unfiled) out += '<p class="muted">And ' + unfiled + ' more under no sphere.</p>';
      if (asks.length) out += '<p><a href="#inbox">' + asks.length + ' waiting for you</a>: ' + asks.map(function (a) { return namedText(a.title, byId); }).join('; ') + '</p>';
      out += '<p><a href="#body/' + esc(s.id) + '">share or stop sharing it</a> &middot; <a href="#sharing">all sharing</a></p>';
      out += '</div>';
    });
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
    bodies: bodies, body: body, inbox: inbox, settings: settings, keys: keys, spheres: spheres, locationCard: locationCard, pairingCard: pairingCard, byWho: byWho, sharing: sharing, bodySharingCard: bodySharingCard, forWhom: forWhom, assignBox: assignBox,
    personPicker: personPicker, matchScore: matchScore, pickMatches: pickMatches, pickList: pickList, payloadLine: payloadLine, namedText: namedText, esc: esc, fmtValue: fmtValue,
    seg: seg, route: route, sseEvent: sseEvent, graphOf: graphOf, nodePane: nodePane, edgePane: edgePane, dupesOf: dupesOf, tidyCard: tidyCard, prefsCard: prefsCard, qualityCard: qualityCard, correctionsCard: correctionsCard, instructBox: instructBox, notTrue: notTrue,
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
  var graphPos = Object.create(null), graphView = { zoom: 1, px: 0, py: 0, picked: null, focus: null, past: false, hidden: Object.assign({}, DEFAULT_HIDDEN), touching: 0 }, graphTimer = null, graphState = null;
  function palette() {
    var cs = getComputedStyle(document.documentElement);
    function v(name, dflt) { return (cs.getPropertyValue(name) || '').trim() || dflt; }
    return { ink: v('--ink', '#101541'), muted: v('--muted', '#6b6f80'), card: v('--card', '#ffffff') };
  }
  function mountGraph(state) {
    graphState = state;
    var canvas = document.getElementById('graph');
    if (!canvas) return;
    var pane = document.getElementById('graph-pane'), find = document.getElementById('graph-find'), pastBox = document.getElementById('graph-past'), kindBoxes = document.querySelectorAll('[data-kind]'), aloneEl = document.getElementById('graph-alone');
    pastBox.checked = graphView.past;
    Array.prototype.forEach.call(kindBoxes, function (b) { b.checked = !graphView.hidden[b.dataset.kind]; });
    // the pane lists every connection, events too, whatever the diagram shows
    var g = graphOf(state, graphView.past, graphView.hidden), full = graphOf(state, graphView.past), ctx = canvas.getContext('2d');
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
    Array.prototype.forEach.call(kindBoxes, function (b) {
      b.onchange = function () {
        if (b.checked) delete graphView.hidden[b.dataset.kind]; else graphView.hidden[b.dataset.kind] = true;
        unmountGraph(); mountGraph(graphState);
      };
    });
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
    var name = r.name === 'body' || r.name === 'inbox' || r.name === 'settings' || r.name === 'keys' || r.name === 'spheres' || r.name === 'sharing' ? r.name : 'bodies';
    return { r: r, name: name, here: name + ' ' + (r.id || ''), cached: name !== 'settings' && name !== 'keys' && name !== 'sharing' };
  }
  // one view drawn from its answer, through show, which may hold it
  function drawView(v, d, show) {
    if (v.name !== 'bodies') unmountGraph();
    if (v.name === 'body') { var drewBody = show(body(d[0], d[1])); if (drewBody) fillBodySharing(); return drewBody; }
    if (v.name === 'sharing') return show(sharing(d[0], d[1], d[2], d[3], d[4], d[5]));
    if (v.name === 'inbox') return show(inbox(openActions(d), d));
    if (v.name === 'settings') {
      var l = d.chat_lists || {};
      var drew = show(settings(d.schema, d.policy, d.generator, d.generator_last, d.reconcile_last, d.telegram, d.telegram_last, d.exec_last, d.chat, d.chat_last, l.dms, l.channels, d.calendar_last, d.mail, d.mail_last, d.brief_last, d.read, d.read_last, d.reasons, d.tally, d.corrections, d.travel, d.travel_last,
        { review: d.review_last, healthDays: d.health_days, health: d.health_last, work: d.work_last, nudge: d.nudge_last, rhythm: d.rhythm, outdoors: d.outdoors, weather: d.weather_last, parks: d.parks_last, search: d.search, searchLast: d.search_last }));
      if (drew) fillCalendars();
      return drew;
    }
    if (v.name === 'keys') return show(keys(d[0], d[1], minted));
    if (v.name === 'spheres') { var shown = show(spheres(d)); if (shown) fillPairing(); return shown; }
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
      if (v.name === 'sharing') return Promise.all([lastState ? Promise.resolve(lastState) : api('/state'), api('/shares'), api('/location'), api('/pairing'), api('/policy'), api('/private')]);
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
      if (viewNow().here !== v.here || again) { if (!held) { say(pending); pending = ''; } return; }
      drawView(v, d, show);
      if (!held) { say(pending); pending = ''; }
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
  // location shared for a while (version 88): who you share with and
  // until when, who shares with you and how far from home, and a form
  function locationCard(loc) {
    loc = loc || {};
    var out = '<div class="card" id="location-card"><h2>Location</h2><p class="muted">Share where you are with someone for a while; it stops by itself at the time you set, or when you get home. ' +
      'Your position is never kept as a fact, and the other ship keeps only the latest.</p>';
    var mine = loc.out || [], theirs = loc.in || [], peers = loc.peers || [];
    var nameOf = function (ship) { var p = peers.filter(function (x) { return x.ship === ship; })[0]; return p ? p.name : ship; };
    if (mine.length) out += '<ul>' + mine.map(function (g) {
      return '<li>Sharing with ' + esc(nameOf(g.ship)) + ' ' + (g.until ? 'until ' + fmtTime(g.until) : '') + (g.home ? (g.until ? ' or ' : '') + 'until you are home' : '') +
        (g.exact ? '' : ', to about a kilometre') + ' <button class="small" data-loc-stop="' + esc(g.ship) + '">stop</button></li>';
    }).join('') + '</ul>';
    if (theirs.length) out += '<ul>' + theirs.map(function (e) {
      return '<li>' + esc(e.name || e.ship) + ' is sharing: ' + (e.km_from_home != null ? esc(String(e.km_from_home)) + ' km from home' : 'where they are') + ', ' + fmtTime(e.at) +
        (e.until ? ', until ' + fmtTime(e.until) : '') + '</li>';
    }).join('') + '</ul>';
    if (!peers.length) return out + '<p class="muted">No one here has a ship to share with yet.</p></div>';
    out += '<div id="loc-form"><p><label class="field">with <select name="ship">' + peers.map(function (p) { return '<option value="' + esc(p.ship) + '">' + esc(p.name) + '</option>'; }).join('') + '</select></label> ' +
      '<label class="field">for hours <input name="hours" value="2"></label> ' +
      '<label class="field"><input type="checkbox" name="home"> or until I am home</label> ' +
      '<label class="field"><input type="checkbox" name="exact"> exact (else about a kilometre)</label></p>' +
      '<p><button data-loc-share="1">share my location</button></p></div></div>';
    return out;
  }
  // ==  sharing (version 95): one page for every share, and a card on each
  // body. The people a share can go to are the people here with a ship.
  function shipPeople(state) {
    return ((state && state.bodies) || []).filter(function (b) { return b.kind === 'person' && b.ship && b.id !== 'person/me'; });
  }
  function nameOfShip(ship, state) {
    var p = ((state && state.bodies) || []).filter(function (b) { return b.ship === ship; })[0];
    return p ? (p.name || p.id) : ship;
  }
  function nameOfBody(id, state) {
    var b = ((state && state.bodies) || []).filter(function (x) { return x.id === id; })[0];
    return b ? (b.name || b.id) : id;
  }
  function bodyLink(id, state) { return '<a href="#body/' + esc(id) + '">' + esc(nameOfBody(id, state)) + '</a>'; }
  // a person picker (version 95): a box that finds people as you type, by
  // name, nickname, ship or id, close matches first; the one picked rides
  // in a hidden field of the given name. Long lists stay usable. All spans:
  // a picker sits in a <p>, which a <ul> would close and leave behind.
  function personPicker(name, people, opts) {
    opts = opts || {};
    var data = (opts.blank ? [{ v: '', t: opts.blank, s: '', a: [], id: '' }] : []).concat(people.map(function (p) {
      return { v: opts.ships ? (p.ship || '') : p.id, t: p.name || p.id, s: p.ship || '', a: (p.aliases || []).filter(function (x) { return x && x !== p.name; }).slice(0, 6), id: p.id };
    }));
    var cur = data.filter(function (d) { return opts.current != null && d.v === opts.current; })[0];
    return '<span class="picker" data-picker="' + esc(JSON.stringify(data)) + '">' +
      '<input class="picker-q" aria-label="find a person" placeholder="' + esc(opts.placeholder || 'type a name, nickname or ship') + '" autocomplete="off" value="' + esc(cur ? cur.t : '') + '">' +
      '<input type="hidden" name="' + esc(name) + '" value="' + esc(cur ? cur.v : '') + '">' +
      '<span class="picker-list" role="listbox" hidden></span></span>';
  }
  // how well a typed phrase finds a person: the whole word, a word's start,
  // inside a word, or its letters in order; 0 when it does not
  function matchScore(q, text) {
    q = String(q || '').trim().toLowerCase(); text = String(text || '').toLowerCase();
    if (!q || !text) return 0;
    if (text === q) return 100;
    if (text.indexOf(q) === 0) return 80;
    if (text.split(/[^a-z0-9~]+/).some(function (w) { return w.indexOf(q) === 0; })) return 70;
    if (text.indexOf(q) >= 0) return 60;
    var i = 0, gaps = 0, last = -1;
    for (var j = 0; j < text.length && i < q.length; j++) if (text.charAt(j) === q.charAt(i)) { if (last >= 0) gaps += j - last - 1; last = j; i += 1; }
    return i === q.length ? Math.max(1, 30 - gaps) : 0;
  }
  function pickMatches(data, q, n) {
    n = n || 8;
    if (!String(q || '').trim()) return data.slice().sort(function (a, b) { return a.v === '' ? -1 : b.v === '' ? 1 : String(a.t).localeCompare(String(b.t)); }).slice(0, n);
    return data.map(function (d) {
      var best = Math.max.apply(null, [matchScore(q, d.t), matchScore(q, d.s) - 5, matchScore(q, d.id) - 10].concat(d.a.map(function (x) { return matchScore(q, x) - 2; })));
      return { d: d, s: best };
    }).filter(function (x) { return x.s > 0; }).sort(function (a, b) { return b.s - a.s || String(a.d.t).localeCompare(String(b.d.t)); }).slice(0, n).map(function (x) { return x.d; });
  }
  function pickList(data, q) {
    var hits = pickMatches(data, q);
    if (!hits.length) return '<span class="pick muted">no one by that</span>';
    return hits.map(function (d, i) {
      var also = [d.s].concat(d.a).filter(Boolean).map(esc).join(' &middot; ');
      return '<span role="option" data-pick="' + esc(d.v) + '" data-pick-text="' + esc(d.t) + '" class="pick' + (i === 0 ? ' on' : '') + '">' + esc(d.t) + (also ? ' <span class="muted">' + also + '</span>' : '') + '</span>';
    }).join('');
  }
  function personOptions(people, blank) {
    return (blank ? '<option value="">' + esc(blank) + '</option>' : '') +
      people.map(function (p) { return '<option value="' + esc(p.ship || p.id) + '">' + esc(p.name || p.id) + (p.ship ? ' (' + esc(p.ship) + ')' : '') + '</option>'; }).join('');
  }
  function modeSelect(name) {
    return '<select name="' + name + '"><option value="edit">they can edit</option><option value="read">read only</option></select>';
  }
  function lastLine(row) {
    row = row || {};
    return (row.last ? 'last read ' + fmtTime(row.last) : 'not read yet') + (row.error ? ' &middot; <span class="bad">' + esc(row.error) + '</span>' : '');
  }
  function obj(x) { return x && typeof x === 'object' && !Array.isArray(x) ? x : {}; }
  function sharing(state, shares, loc, pairs, policy, priv) {
    shares = obj(shares);
    var spheresHere = ((state && state.bodies) || []).filter(function (b) { return b.kind === 'sphere'; });
    if (!spheresHere.some(function (s) { return s.id === 'sphere/home'; })) spheresHere.unshift({ id: 'sphere/home', name: 'Home' });
    var people = shipPeople(state);
    var follows = obj(shares.sphere_follows), sphereShares = obj(shares.sphere_shares);
    var out = '<h1>Sharing</h1><p class="muted">What you share with other ships, what they share with you, and what you are asked. ' +
      'A sphere shares every body in it, both ways when they can edit; a body or a situation can be shared alone.</p>';
    // waiting for you: offers, and matches to pair
    var sOffers = Object.keys(obj(shares.sphere_offers)).map(function (k) { return obj(shares.sphere_offers[k]); });
    var bOffers = Object.keys(obj(shares.offers)).map(function (k) { return obj(shares.offers[k]); });
    out += '<div class="card" id="sharing-waiting"><h2>Waiting for you</h2>';
    if (!sOffers.length && !bOffers.length && !(pairs || []).length) out += '<p class="muted">Nothing waiting.</p>';
    if (sOffers.length || bOffers.length) {
      out += '<ul>' + sOffers.map(function (o) {
        var at = 'data-host="' + esc(o.host) + '" data-sphere="' + esc(o.sphere) + '"';
        return '<li>The sphere <strong>' + esc(o.name || o.sphere) + '</strong> from ' + esc(nameOfShip(o.host, state)) + ' <span class="muted">' + (o.mode === 'edit' ? 'you can edit' : 'read only') + '</span> ' +
          '<button class="small" data-accept-sphere="1" ' + at + '>accept</button> <button class="small danger" data-decline-sphere="1" ' + at + '>decline</button></li>';
      }).join('') + bOffers.map(function (o) {
        var at = 'data-host="' + esc(o.host) + '" data-id="' + esc(o.id) + '"';
        return '<li><strong>' + esc(o.name || o.id) + '</strong> <span class="muted">' + esc(o.id) + '</span> from ' + esc(nameOfShip(o.host, state)) + ' <span class="muted">' + (o.mode === 'edit' ? 'you can edit' : 'read only') + '</span> ' +
          '<button class="small" data-accept-body="1" ' + at + '>accept</button> <button class="small danger" data-decline-body="1" ' + at + '>decline</button></li>';
      }).join('') + '</ul>';
    }
    out += '</div>' + pairingCard(pairs);
    // spheres you share; the feed kept back for a host is part of following
    var backFor = {};
    Object.keys(follows).forEach(function (k) { var f = obj(follows[k]); if (f.role === 'peer') backFor[f.local + '|' + f.host] = true; });
    out += '<div class="card" id="sharing-spheres"><h2>Spheres you share</h2>';
    var mine = Object.keys(sphereShares).filter(function (s) { return Object.keys(obj(sphereShares[s])).some(function (ship) { return !backFor[s + '|' + ship]; }); });
    if (!mine.length) out += '<p class="muted">No sphere shared yet.</p>';
    else out += '<ul>' + mine.map(function (s) {
      var ships = Object.keys(obj(sphereShares[s])).filter(function (ship) { return !backFor[s + '|' + ship]; });
      return '<li>' + bodyLink(s, state) + ' with ' + ships.map(function (ship) {
        var reading = Object.keys(follows).map(function (k) { return obj(follows[k]); }).filter(function (f) { return f.role === 'host' && f.local === s && f.host === ship; })[0];
        return esc(nameOfShip(ship, state)) + ' <span class="muted">' + (sphereShares[s][ship] === 'edit' ? 'can edit' : 'read only') +
          (reading ? ' &middot; their edits: ' + lastLine(reading) : '') + '</span> <button class="small danger" data-unshare-sphere="' + esc(s) + '" data-ship="' + esc(ship) + '">stop</button>';
      }).join('; ') + '</li>';
    }).join('') + '</ul>';
    if (!people.length) out += '<p class="muted">To share, add a person with their ship: a person body with a ship.</p>';
    else out += '<div id="share-sphere-form"><p><label class="field">sphere <select name="sphere"><option value="">choose a sphere</option>' + spheresHere.map(function (s) { return '<option value="' + esc(s.id) + '">' + esc(s.name || s.id) + (s.id === 'sphere/home' ? ' (every body filed under none)' : '') + '</option>'; }).join('') + '</select></label> ' +
      '<label class="field">with ' + personPicker('ship', people, { ships: true }) + '</label> <label class="field">' + modeSelect('mode') + '</label> ' +
      '<button data-share-sphere="1">share the sphere</button></p>' +
      '<p class="muted">Sharing Home shares every body filed under no sphere. They are offered it and must accept; what is kept private, and sensitive attributes, stay here.</p></div>';
    out += '</div>';
    // spheres shared with you
    var theirs = Object.keys(follows).map(function (k) { return obj(follows[k]); }).filter(function (f) { return f.role === 'peer'; });
    out += '<div class="card" id="sharing-followed"><h2>Spheres shared with you</h2>';
    if (!theirs.length) out += '<p class="muted">None.</p>';
    else out += '<ul>' + theirs.map(function (f) {
      var waiting = (f.pending || []).length;
      return '<li>' + bodyLink(f.local, state) + ' from ' + esc(nameOfShip(f.host, state)) + ' <span class="muted">' + (f.mode === 'edit' ? 'you can edit' : 'read only') + ' &middot; ' + lastLine(f) +
        (waiting ? ' &middot; ' + waiting + ' to pair' : '') + '</span> <button class="small" data-sync="1">read now</button> ' +
        '<button class="small danger" data-sphere-leave="1" data-host="' + esc(f.host) + '" data-sphere="' + esc(f.sphere) + '">leave</button></li>';
    }).join('') + '</ul>';
    out += '</div>';
    // bodies, alone
    var bShares = obj(shares.shares), accepted = obj(shares.accepted);
    out += '<div class="card" id="sharing-bodies"><h2>Bodies shared alone</h2>';
    var bIds = Object.keys(bShares).filter(function (id) { return Object.keys(obj(bShares[id])).length; });
    var acc = Object.keys(accepted).map(function (k) { return obj(accepted[k]); });
    if (!bIds.length && !acc.length) out += '<p class="muted">None. Share a body from its page.</p>';
    var viaSit = function (id, ship) { return Object.keys(obj(obj(shares.situation_shares)[id])).some(function (p) { return obj(shares.situation_shares[id][p]).ship === ship; }); };
    if (bIds.length) out += '<h3>You share</h3><ul>' + bIds.map(function (id) {
      return '<li>' + bodyLink(id, state) + ' with ' + Object.keys(obj(bShares[id])).map(function (ship) {
        return esc(nameOfShip(ship, state)) + ' <span class="muted">' + (bShares[id][ship] === 'edit' ? 'can edit' : 'read only') + '</span> ' +
          (viaSit(id, ship) ? '<span class="muted">through the situation\'s shared-with; remove them on its page</span>'
            : '<button class="small danger" data-unshare-body="' + esc(id) + '" data-ship="' + esc(ship) + '">stop</button>');
      }).join('; ') + '</li>';
    }).join('') + '</ul>';
    if (acc.length) out += '<h3>Shared with you</h3><ul>' + acc.map(function (r) {
      return '<li>' + bodyLink(r.target || r.id, state) + ' from ' + esc(nameOfShip(r.host, state)) + ' <span class="muted">' + (r.mode === 'edit' ? 'you can edit' : 'read only') + ' &middot; ' + lastLine(r) + '</span> ' +
        '<button class="small danger" data-leave-body="1" data-host="' + esc(r.host) + '" data-id="' + esc(r.id) + '">leave</button></li>';
    }).join('') + '</ul>';
    out += '</div>';
    // situations, alone
    var sits = obj(shares.situation_shares);
    var sitIds = Object.keys(sits);
    out += '<div class="card" id="sharing-situations"><h2>Situations shared alone</h2>';
    if (!sitIds.length) out += '<p class="muted">None. Share a situation from its page; it ends a day after the situation does.</p>';
    else out += '<ul>' + sitIds.map(function (sid) {
      var who = obj(sits[sid]);
      return '<li>' + bodyLink(sid, state) + ': ' + Object.keys(who).map(function (p) {
        var e = obj(who[p]);
        return bodyLink(p, state) + ' <span class="muted">' + (e.ship ? 'on their orrery' : e.via ? 'invited by ' + esc(e.via === 'mail' ? 'email' : e.via) : esc(e.note || 'not reached')) + '</span>';
      }).join('; ') + '</li>';
    }).join('') + '</ul>';
    out += '</div>';
    // location, the pushes, private rows
    out += locationCard(loc);
    var widen = obj(policy).peer_push === 'all';
    out += '<div class="card" id="sharing-pushes"><h2>What reaches your phone</h2><p class="muted">Everything shared replicates; this is only what is pushed.</p>' +
      '<p><label class="box"><input type="radio" name="peer_push" value="asks"' + (widen ? '' : ' checked') + '> only what asks something of me: a task for me, a leg that is now mine</label></p>' +
      '<p><label class="box"><input type="radio" name="peer_push" value="all"' + (widen ? ' checked' : '') + '> every change</label></p>' +
      '<p><button data-save-peer-push="1">save</button></p></div>';
    var n = ((obj(priv).ids) || []).length;
    out += '<div class="card"><h2>Kept to yourself</h2><p class="muted">' + (n ? n + (n === 1 ? ' row is' : ' rows are') + ' kept to yourself: never in a shared sphere\'s feed.' : 'No row is kept to yourself.') +
      ' Each body page lets you keep a row to yourself, or share it again.</p></div>';
    return out;
  }
  // the card on a body's page: who it is shared with and the form to
  // share it (a sphere's whole; a situation's alone, by person); the rows
  // the owner may keep to themselves when the body is in a shared sphere
  function bodySharingCard(v, state, shares, priv) {
    v = v || {}; shares = obj(shares);
    var people = shipPeople(state), everyone = ((state && state.bodies) || []).filter(function (b) { return b.kind === 'person' && b.id !== 'person/me'; });
    var out = '<div class="card" id="body-sharing" data-id="' + esc(v.id) + '"><h2>Sharing</h2>';
    if (v.kind === 'sphere') {
      var with_ = obj(obj(shares.sphere_shares)[v.id]);
      var ships = Object.keys(with_);
      out += ships.length ? '<p>This sphere is shared with ' + ships.map(function (s) {
        return esc(nameOfShip(s, state)) + ' <span class="muted">' + (with_[s] === 'edit' ? 'can edit' : 'read only') + '</span> <button class="small danger" data-unshare-sphere="' + esc(v.id) + '" data-ship="' + esc(s) + '">stop</button>';
      }).join('; ') + '</p>' : '<p class="muted">Not shared.</p>';
      if (people.length) out += '<div id="share-sphere-form"><input type="hidden" name="sphere" value="' + esc(v.id) + '"><p><label class="field">share it with ' + personPicker('ship', people, { ships: true }) + '</label> ' +
        '<label class="field">' + modeSelect('mode') + '</label> <button data-share-sphere="1">share the sphere</button></p></div>';
      return out + '</div>';
    }
    if (v.id !== 'person/me') {
      var bw = obj(obj(shares.shares)[v.id]);
      var sitWith = obj(obj(shares.situation_shares)[v.id]);
      var bs = Object.keys(bw).filter(function (s) { return !Object.keys(sitWith).some(function (p) { return obj(sitWith[p]).ship === s; }); });
      out += bs.length ? '<p>Shared alone with ' + bs.map(function (s) {
        return esc(nameOfShip(s, state)) + ' <span class="muted">' + (bw[s] === 'edit' ? 'can edit' : 'read only') + '</span> <button class="small danger" data-unshare-body="' + esc(v.id) + '" data-ship="' + esc(s) + '">stop</button>';
      }).join('; ') + '</p>' : '';
      if (people.length) out += '<div id="share-body-form"><p><label class="field">share this alone with ' + personPicker('ship', people, { ships: true }) + '</label> ' +
        '<label class="field">' + modeSelect('mode') + '</label> <button data-share-body="' + esc(v.id) + '">share</button></p></div>';
    }
    if (v.kind === 'situation') {
      var rows = (function (r) { return !r ? [] : Array.isArray(r) ? r : [r]; })((v.attrs || {})['shared-with']);
      var how = obj(obj(shares.situation_shares)[v.id]);
      out += '<h3>Shared with, just this situation</h3>';
      out += rows.length ? '<ul>' + rows.map(function (r) {
        var p = r.value && r.value.ref, e = obj(how[p]);
        return '<li>' + bodyLink(p, state) + ' <span class="muted">' + (e.ship ? 'on their orrery' : e.via ? 'invited by ' + esc(e.via === 'mail' ? 'email' : e.via) : e.note ? esc(e.note) : 'on the next pass') + '</span> ' +
          '<button class="small danger" data-unshare-situation="' + esc(r.obs || '') + '">remove</button></li>';
      }).join('') + '</ul>' : '<p class="muted">With no one. Someone with orrery is offered it; anyone else gets an invitation, sent again when the time, place or what is needed changes. It ends a day after the situation does.</p>';
      if (everyone.length) out += '<div id="share-situation-form"><p><label class="field">share with ' + personPicker('who', everyone) + '</label> ' +
        '<button data-share-situation="' + esc(v.id) + '">add</button></p></div>';
    }
    // a body in a shared sphere: the owner's own rows may be kept back
    var shared = Object.keys(obj(shares.sphere_shares)).filter(function (s) { return Object.keys(obj(shares.sphere_shares[s])).length; });
    var filed = (function (r) { return !r ? [] : Array.isArray(r) ? r : [r]; })((v.attrs || {}).sphere).map(function (r) { return r.value && r.value.ref; });
    var inShared = v.kind !== 'sphere' && (filed.length ? filed.some(function (s) { return shared.indexOf(s) >= 0; }) : shared.indexOf('sphere/home') >= 0);
    if (inShared) {
      var ids = (obj(priv).ids || []);
      var own = [];
      Object.keys(v.attrs || {}).forEach(function (a) {
        if (a === 'twin' || a === 'sphere') return;
        (function (r) { return !r ? [] : Array.isArray(r) ? r : [r]; })(v.attrs[a]).forEach(function (r) { if (r && r.obs && String(r.by || '').charAt(0) !== '~') own.push({ a: a, r: r }); });
      });
      out += '<h3>In a shared sphere</h3><p class="muted">Your rows go to who you share it with. Keep one to yourself and it never goes.</p>';
      out += own.length ? '<ul>' + own.map(function (x) {
        var kept = ids.indexOf(x.r.obs) >= 0;
        return '<li>' + esc(x.a) + ': ' + fmtValue(x.r.value) + ' ' + (kept ? '<span class="muted">kept to yourself</span> ' : '') +
          '<button class="small" data-private="' + esc(x.r.obs) + '" data-keep="' + (kept ? '0' : '1') + '">' + (kept ? 'share it' : 'keep to myself') + '</button></li>';
      }).join('') + '</ul>' : '<p class="muted">No rows of yours here.</p>';
    }
    return out + '</div>';
  }
  function fillBodySharing() {
    var slot = document.getElementById('body-sharing');
    if (!slot) return;
    var id = slot.dataset.id;
    Promise.all([api('/body/' + seg(id)), api('/shares'), api('/private')]).then(function (d) {
      var now = document.getElementById('body-sharing');
      if (now && now.dataset.id === id) now.outerHTML = bodySharingCard(d[0], lastState, d[1], d[2]);
    }).catch(function () { /* the card keeps its words */ });
  }
  // after a share moves: the view again, and the body card
  // what a sharing button did, said again once the redraw is done
  var pending = '';
  function shared(msg) { say(msg); pending = msg; setTimeout(function () { refresh(true); fillBodySharing(); }, 800); }
  // pairing (version 91): a sphere another ship shares is matched to what
  // you hold before any of it comes in; a match by name only is yours to
  // say is the same thing, or not
  function pairingCard(list) {
    list = Array.isArray(list) ? list : [];
    if (!list.length) return '<div id="pairing-card"></div>';
    return '<div class="card" id="pairing-card"><h2>To pair</h2><p class="muted">A sphere shared with you waits for these before it comes in: ' +
      'the same name, here and there. Say whether each is the same.</p><ul>' + list.map(function (p) {
        var at = 'data-pair-key="' + esc(p.key) + '" data-pair-there="' + esc(p.there) + '"';
        return '<li>' + esc(p.there_name || p.there) + ' <span class="muted">on ' + esc(p.host) + '</span> and <a href="#body/' + esc(p.here) + '">' + esc(p.here_name || p.here) + '</a> here ' +
          '<button class="small" ' + at + ' data-pair-same="1">same</button> <button class="small" ' + at + ' data-pair-same="0">different</button></li>';
      }).join('') + '</ul></div>';
  }
  function fillPairing() {
    if (!document.getElementById('pairing-card')) return;
    fetch(API + '/pairing', { credentials: 'include' }).then(function (r) { return r.ok ? r.json() : []; }).then(function (list) {
      var slot = document.getElementById('pairing-card');
      if (slot) slot.outerHTML = pairingCard(list);
    }).catch(function () { /* nothing waits */ });
  }
  function fillLocation() {
    var slot = document.getElementById('location-card');
    if (!slot) return;
    fetch(API + '/location', { credentials: 'include' }).then(function (r) { return r.ok ? r.json() : null; }).then(function (loc) {
      if (loc && document.getElementById('location-card')) document.getElementById('location-card').outerHTML = locationCard(loc);
    }).catch(function () { /* the card keeps its words */ });
  }
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
  function typedNote() { return Array.prototype.some.call(view.querySelectorAll('[data-refine-text], [data-instruct-text]'), function (i) { return !!i.value.trim(); }); }
  // after the owner's own move the refresh looks again each second until
  // the move shows: the writer applies it a while after the answer, and
  // the beacon's news can lag a minute. A merge or a delete shows when
  // the body is gone from the state (the rev also moves for the ship's
  // other writes meanwhile); any other move when the rev moves.
  var awaitMove = 0, awaitGone = null, tidyGone = Object.create(null);
  // A handler given straight to .then hands its answer in: only a list
  // names bodies to wait for. An answer taken for one threw in every
  // refresh after, and the page stopped updating (6de6141 to 90d8086).
  function later(gone) { dirty = typedNote(); awaitGone = Array.isArray(gone) ? gone : null; awaitMove = awaitGone ? 20 : 10; setTimeout(function () { refresh(!dirty); }, 300); }

  // the person pickers: the list follows what is typed; a click or Enter
  // picks; leaving the box closes it. Typing clears the pick, so a share
  // goes only to someone picked.
  function pickerOf(el) { return el && el.closest ? el.closest('.picker') : null; }
  function pickerData(pk) { try { return JSON.parse(pk.dataset.picker || '[]'); } catch (e) { return []; } }
  function pickerShow(pk) {
    var list = pk.querySelector('.picker-list');
    list.innerHTML = pickList(pickerData(pk), pk.querySelector('.picker-q').value);
    list.hidden = false;
  }
  function pickerPick(pk, li) {
    if (!li || !li.hasAttribute('data-pick')) return;
    pk.querySelector('input[type="hidden"]').value = li.getAttribute('data-pick');
    pk.querySelector('.picker-q').value = li.getAttribute('data-pick-text');
    pk.querySelector('.picker-list').hidden = true;
  }
  view.addEventListener('input', function (ev) {
    var pk = pickerOf(ev.target);
    if (!pk || !ev.target.classList.contains('picker-q')) return;
    pk.querySelector('input[type="hidden"]').value = '';
    pickerShow(pk);
  });
  view.addEventListener('focusin', function (ev) {
    var pk = pickerOf(ev.target);
    if (pk && ev.target.classList.contains('picker-q')) pickerShow(pk);
  });
  view.addEventListener('focusout', function (ev) {
    var pk = pickerOf(ev.target);
    if (pk) setTimeout(function () { if (!pk.contains(document.activeElement)) pk.querySelector('.picker-list').hidden = true; }, 150);
  });
  view.addEventListener('keydown', function (ev) {
    var pk = pickerOf(ev.target);
    if (!pk || !ev.target.classList.contains('picker-q')) return;
    var list = pk.querySelector('.picker-list'), items = Array.prototype.slice.call(list.querySelectorAll('.pick[data-pick]'));
    var at = items.findIndex(function (li) { return li.classList.contains('on'); });
    if (ev.key === 'ArrowDown' || ev.key === 'ArrowUp') {
      ev.preventDefault();
      if (list.hidden) pickerShow(pk);
      items = Array.prototype.slice.call(list.querySelectorAll('.pick[data-pick]'));
      if (!items.length) return;
      var next = ev.key === 'ArrowDown' ? Math.min(items.length - 1, at + 1) : Math.max(0, at - 1);
      items.forEach(function (li, i) { li.classList.toggle('on', i === next); });
    } else if (ev.key === 'Enter') {
      ev.preventDefault();
      pickerPick(pk, items[at >= 0 ? at : 0]);
    } else if (ev.key === 'Escape') {
      list.hidden = true;
    }
  });
  view.addEventListener('mousedown', function (ev) {
    var li = ev.target.closest && ev.target.closest('.picker-list [data-pick]');
    if (li) { ev.preventDefault(); pickerPick(pickerOf(li), li); }
  });
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
    } else if (b.dataset.correct) {
      var cwhy = prompt('Why is "' + b.dataset.value + '" wrong? It goes from every source, and the ship will not write it again.');
      if (cwhy === null) return;
      working(b, 'striking');
      post('/correct', { subject: b.dataset.correct, attr: b.dataset.attr, value: b.dataset.value, why: cwhy.trim().slice(0, 500) })
        .then(function () { b.textContent = 'struck'; say('struck: it goes from every source'); later(); }).catch(function (e) { unsettled(b); oops(e); });
    } else if (b.dataset.uncorrect) {
      working(b, 'undoing');
      api('/corrections/' + seg(b.dataset.uncorrect), { method: 'DELETE' }).then(function () { var li = b.closest('li'); if (li) li.remove(); say('taken back: the value may be written again'); }).catch(function (e) { unsettled(b); oops(e); });
    } else if (b.dataset.instruct) {
      var ik = b.dataset.instruct, cut0 = ik.indexOf('|');
      var ibox = view.querySelector('[data-instruct-text="' + ik + '"]'), inote = view.querySelector('[data-instruct-note="' + ik + '"]');
      var itext = ibox ? ibox.value.trim() : '';
      if (!itext) { if (inote) inote.textContent = 'type an instruction first'; return; }
      var ireq = { text: itext, apply: !b.dataset.propose };
      if (ik.slice(0, cut0)) ireq.about = [ik.slice(0, cut0)];
      if (ik.slice(cut0 + 1)) ireq.action = ik.slice(cut0 + 1);
      working(b, 'thinking');
      post('/instruct', ireq).then(function (d) {
        var el = view.querySelector('[data-instruct-note="' + ik + '"]'), box = view.querySelector('[data-instruct-text="' + ik + '"]');
        var n = (d.actions || []).length;
        replied[ik] = (d.reply || '') + (n ? ' (' + n + (ireq.apply ? ' approved)' : ' proposed)') : '') + (d.note ? ' ' + d.note : '');
        if (el) el.textContent = replied[ik];
        if (box) box.value = '';
        dirty = typedNote();
        unsettled(b);
        say(n ? (ireq.apply ? 'done: the writer applies it' : 'proposed: see the inbox') : 'answered');
        if (n) later();
      }).catch(function (e) { unsettled(b); var el = view.querySelector('[data-instruct-note="' + ik + '"]'); if (el) el.textContent = e.message; });
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
    } else if (b.dataset.saveTravel) {
      var tv = function (name) { return field('#travel', name); };
      var tf = { enabled: !!view.querySelector('#travel input[name="enabled"]:checked'), lead_min: numOrNull(tv('lead_min')), buffer_min: numOrNull(tv('buffer_min')) };
      if (tv('token')) tf.token = tv('token');
      say('saving time to leave');
      post('/travel', tf, 'PUT').then(function () { dirty = false; say('time to leave saved'); }).catch(oops);
    } else if (b.dataset.saveRhythm) {
      var rv = function (name) { return field('#rhythm', name); };
      var rf = {};
      ['quiet_from', 'quiet_to', 'family_from', 'family_to', 'evening_from', 'evening_to', 'weekend_from', 'weekend_to'].forEach(function (k) { rf[k] = rv(k); });
      ['per_window', 'young_age', 'young_share'].forEach(function (k) { rf[k] = numOrNull(rv(k)); });
      say('saving your day');
      post('/rhythm', rf, 'PUT').then(function () { dirty = false; say('your day saved'); }).catch(oops);
    } else if (b.dataset.locShare) {
      var lv = function (name) { return field('#loc-form', name); };
      var lf = { ship: (view.querySelector('#loc-form select[name="ship"]') || {}).value, hours: numOrNull(lv('hours')),
        home: !!view.querySelector('#loc-form input[name="home"]:checked'), precision: view.querySelector('#loc-form input[name="exact"]:checked') ? 'exact' : 'area' };
      if (lf.home && !lv('hours')) delete lf.hours;
      say('sharing your location');
      post('/location/share', lf).then(function () { say('location shared'); fillLocation(); }).catch(oops);
    } else if (b.dataset.acceptSphere) {
      post('/sphere-accept', { host: b.dataset.host, sphere: b.dataset.sphere }).then(function () { shared('accepted: the sphere comes in once any matches are paired'); }).catch(oops);
    } else if (b.dataset.declineSphere) {
      post('/sphere-decline', { host: b.dataset.host, sphere: b.dataset.sphere }).then(function () { shared('declined'); }).catch(oops);
    } else if (b.dataset.acceptBody) {
      post('/accept', { host: b.dataset.host, id: b.dataset.id }).then(function () { shared('accepted'); }).catch(oops);
    } else if (b.dataset.declineBody) {
      post('/decline', { host: b.dataset.host, id: b.dataset.id }).then(function () { shared('declined'); }).catch(oops);
    } else if (b.dataset.shareSphere) {
      var sf = b.closest('#share-sphere-form') || view;
      var sphere = (sf.querySelector('[name="sphere"]') || {}).value, sship = (sf.querySelector('[name="ship"]') || {}).value, smode = (sf.querySelector('[name="mode"]') || {}).value;
      if (!sphere) { say('choose a sphere first', true); return; }
      if (!sship) { say('choose who to share it with: type a name and pick one', true); return; }
      say('sharing the sphere');
      post('/sphere-share', { sphere: sphere, ship: sship, mode: smode }).then(function (r) { shared(r && r.notified ? 'shared: they are offered it' : 'shared, but their ship did not answer; it is offered when it does'); }).catch(oops);
    } else if (b.dataset.unshareSphere) {
      if (!confirm('Stop sharing ' + b.dataset.unshareSphere + ' with ' + b.dataset.ship + '? What they hold stays with them.')) return;
      api('/sphere-share/' + b.dataset.unshareSphere + '/' + encodeURIComponent(b.dataset.ship), { method: 'DELETE' }).then(function () { shared('stopped sharing'); }).catch(oops);
    } else if (b.dataset.sphereLeave) {
      if (!confirm('Leave this sphere? What you hold stays; nothing more comes or goes.')) return;
      post('/sphere-leave', { host: b.dataset.host, sphere: b.dataset.sphere }).then(function () { shared('left the sphere'); }).catch(oops);
    } else if (b.dataset.shareBody) {
      var bf = b.closest('#share-body-form') || view;
      if (!(bf.querySelector('[name="ship"]') || {}).value) { say('choose who to share it with: type a name and pick one', true); return; }
      post('/share', { id: b.dataset.shareBody, ship: (bf.querySelector('[name="ship"]') || {}).value, mode: (bf.querySelector('[name="mode"]') || {}).value })
        .then(function (r) { shared(r && r.notified ? 'shared: they are offered it' : 'shared, but their ship did not answer'); }).catch(oops);
    } else if (b.dataset.unshareBody) {
      if (!confirm('Stop sharing this with ' + b.dataset.ship + '? What they hold stays with them.')) return;
      api('/share/' + b.dataset.unshareBody + '/' + encodeURIComponent(b.dataset.ship), { method: 'DELETE' }).then(function () { shared('stopped sharing'); }).catch(oops);
    } else if (b.dataset.leaveBody) {
      if (!confirm('Stop following this? What you hold stays.')) return;
      post('/leave', { host: b.dataset.host, id: b.dataset.id }).then(function () { shared('left'); }).catch(oops);
    } else if (b.dataset.sync) {
      post('/sync', {}).then(function () { shared('reading now'); }).catch(oops);
    } else if (b.dataset.shareSituation) {
      var who = ((b.closest('#share-situation-form') || view).querySelector('[name="who"]') || {}).value;
      if (!who) { say('choose who to share it with: type a name and pick one', true); return; }
      post('/observe', { bodies: [], observations: [{ subject: b.dataset.shareSituation, attr: 'shared-with', value: { ref: who }, at: new Date().toISOString().replace(/\.\d+Z$/, 'Z'), by: 'owner', source: { kind: 'user', id: 'page' }, conf: 100 }] })
        .then(function () { shared('shared: they are reached on the next pass'); }).catch(oops);
    } else if (b.dataset.unshareSituation) {
      post('/retract', { id: b.dataset.unshareSituation, note: 'no longer shared with them' }).then(function () { shared('removed: their share ends'); }).catch(oops);
    } else if (b.dataset.private) {
      post('/private', { id: b.dataset.private, private: b.dataset.keep === '1' }).then(function () { shared(b.dataset.keep === '1' ? 'kept to yourself' : 'shared again'); }).catch(oops);
    } else if (b.dataset.savePeerPush) {
      var choice = (view.querySelector('input[name="peer_push"]:checked') || {}).value || 'asks';
      api('/policy').then(function (pol) { pol.peer_push = choice; return post('/policy', pol, 'PUT'); }).then(function () { say('saved'); }).catch(oops);
    } else if (b.dataset.assign) {
      var sel = (b.closest('.assign') || view).querySelector('[name="assign-who"]');
      post('/actions/' + seg(b.dataset.assign) + '/assign', { assignee: sel ? sel.value : '' }).then(function () { say('assigned'); later(); }).catch(oops);
    } else if (b.dataset.pairThere) {
      post('/pairing', { key: b.dataset.pairKey, there: b.dataset.pairThere, same: b.dataset.pairSame === '1' })
        .then(function () { say(b.dataset.pairSame === '1' ? 'paired' : 'kept apart'); fillPairing(); }).catch(oops);
    } else if (b.dataset.locStop) {
      api('/location/share/' + encodeURIComponent(b.dataset.locStop), { method: 'DELETE' }).then(function () { say('stopped sharing'); fillLocation(); }).catch(oops);
    } else if (b.dataset.saveSearch) {
      var sv = function (name) { return field('#search', name); };
      var sf = { enabled: !!view.querySelector('#search input[name="enabled"]:checked'), monthly_cap: numOrNull(sv('monthly_cap')) };
      if (sv('api_key')) sf.api_key = sv('api_key');
      say('saving place lookups');
      post('/search', sf, 'PUT').then(function () { dirty = false; say('place lookups saved'); }).catch(oops);
    } else if (b.dataset.saveOutdoors) {
      var ov = function (name) { return field('#outdoors', name); };
      var of = { weather: !!view.querySelector('#outdoors input[name="weather"]:checked'), pota: !!view.querySelector('#outdoors input[name="pota"]:checked'),
        pota_location: ov('pota_location'), pota_radius_km: numOrNull(ov('pota_radius_km')) };
      say('saving outdoors');
      post('/outdoors', of, 'PUT').then(function () { dirty = false; say('outdoors saved'); }).catch(oops);
    } else if (b.dataset.travelWake) {
      post('/travel/wake', {}).then(function () { say('looking now; the card updates in a moment'); setTimeout(refresh, 8000); }).catch(oops);
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
    } else if (b.dataset.reviewWake) {
      post('/review/wake', {}).then(function () { say('review on its way; the card updates when it is sent'); setTimeout(function () { refresh(true); }, 15000); }).catch(oops);
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
