#!/usr/bin/env node
// The page's render functions against fixtures: what the owner sees for
// a state view, a body view, the inbox and the settings. Run: node
// scripts/page-test.js. Exits 1 on the first failed assertion.
'use strict';
process.env.TZ = 'UTC'; // the fixed stamps below are what a reader in UTC sees
const assert = require('assert');
const path = require('path');
const render = require(path.join(__dirname, '..', 'code', 'nex', 'orrery', 'orrery.js'));

const state = {
  rev: 1789600000000, at: '2026-09-17T00:00:00Z', me: 'person/me',
  bodies: [
    { id: 'person/me', kind: 'person', name: 'me', aliases: [], ship: '~wex', attrs: { status: { value: 'home', at: '2026-09-16T22:00:00Z', by: 'talon', source: { kind: 'talon-dm', id: 'm1' }, obs: '1-a' } }, involved: ['situation/2026-09-16-breakdown'] },
    { id: 'thing/subaru', kind: 'thing', name: 'the <b>Subaru</b>', aliases: ['the car'], ship: null, attrs: {}, involved: [] },
    { id: 'situation/2026-09-16-breakdown', kind: 'situation', name: 'breakdown', aliases: [], ship: null, attrs: {}, involved: [] },
    { id: 'situation/2026-09-20-dinner', kind: 'situation', name: 'Dinner at eight', aliases: [], ship: null, attrs: { started: { value: '2099-09-20T23:00:00Z', at: '2026-09-17T00:00:00Z', by: 'talon', source: { kind: 'talon-dm', id: 'm9' }, obs: '3-c' } }, involved: [] },
    { id: 'situation/2026-09-01-preop', kind: 'situation', name: 'PreOp appointment', aliases: [], ship: null, attrs: { status: { value: 'closed', at: '2026-09-01T14:00:00Z', by: 'reconcile', source: { kind: 'reconcile', id: 'r' }, obs: '2-b' } }, involved: [] },
  ],
  situations: ['situation/2026-09-16-breakdown', 'situation/2026-09-20-dinner'],
  actions: [{ id: 'a1', kind: 'task', title: 'Call the shop', status: 'approved', proposed: '2026-09-17T02:10:00Z', by: 'mcp', about: ['thing/subaru'], history: [] }],
  schema: { kinds: {} },
};
const view = {
  id: 'thing/subaru', kind: 'thing', name: 'the Subaru', aliases: ['the car'], ship: null,
  attrs: { location: { value: { ref: 'place/johns-machine-shop' }, at: '2026-09-17T02:10:00Z', until: null, conf: 90, source: { kind: 'talon-dm', id: 'm3' }, by: 'talon', obs: '3-c' } },
  involved: ['situation/2026-09-16-breakdown'],
  actions: [{ id: 'a1', kind: 'task', title: 'Call the shop', status: 'approved', proposed: '2026-09-17T02:10:00Z', by: 'mcp', about: ['thing/subaru'], history: [] }],
  observations: [
    { id: '3-c', attr: 'location', value: { ref: 'place/johns-machine-shop' }, at: '2026-09-17T02:10:00Z', until: null, conf: 90, source: { kind: 'talon-dm', id: 'm3' }, by: 'talon', seen: '2026-09-17T02:10:05Z', status: 'live', retracted: false, note: '' },
    { id: '2-b', attr: 'location', value: 'Route 9', at: '2026-09-16T22:00:00Z', until: null, conf: 90, source: { kind: 'talon-dm', id: 'm1' }, by: 'talon', seen: '2026-09-16T22:00:05Z', status: 'superseded', retracted: false, note: '' },
    { id: '1-a', attr: 'status', value: 'broken down', at: '2026-09-16T22:00:00Z', until: null, conf: 90, source: { kind: 'talon-dm', id: 'm1' }, by: 'talon', seen: '2026-09-16T22:00:05Z', status: 'retracted', retracted: true, note: 'wrong car' },
  ],
};
const inbox = [
  { id: 'p1', kind: 'message', title: 'Tell Sarah the car is at the shop', status: 'proposed', proposed: '2026-09-17T02:11:00Z', by: 'mcp', about: ['person/sarah'], history: [] },
  { id: 'a1', kind: 'task', title: 'Call the shop', status: 'approved', proposed: '2026-09-17T02:10:00Z', by: 'mcp', about: ['thing/subaru'], history: [] },
  { id: 'c1', kind: 'message', title: 'Tell John the car is ready', status: 'claimed', proposed: '2026-09-17T02:12:00Z', by: 'mcp', about: [], history: [
    { at: '2026-09-17T02:12:00Z', status: 'proposed', by: 'mcp' },
    { at: '2026-09-17T02:13:00Z', status: 'approved', by: 'user' },
    { at: '2026-09-17T02:14:00Z', status: 'claimed', by: 'telegram' },
  ] },
];

let n = 0;
function ok(label, cond, detail) { n += 1; assert.ok(cond, label + (detail === undefined ? '' : '   ' + JSON.stringify(detail))); console.log('  ok   ' + label); }

const bodies = render.bodies(state);
ok('the bodies view is a graph with a pane and a finder, the pane naming the colours', bodies.includes('<canvas id="graph"') && bodies.includes('id="graph-pane"') && bodies.includes('id="graph-find"') && bodies.includes('id="graph-past"') && bodies.includes('data-kind="situation"')
  && bodies.includes('class="legend"'));
const g = render.graphOf(state, false), gp = render.graphOf(state, true);
const tiny = render.graphOf({ bodies: [{ id: 'thing/x', kind: 'thing', name: 'x', attrs: { location: { value: { ref: 'place/y' } }, owners: [{ value: { ref: 'person/me' } }, { value: { ref: 'place/y' } }] }, involved: [] }, { id: 'place/y', kind: 'place', name: 'y', attrs: { things: [{ value: { ref: 'thing/x' } }] }, involved: [] }, { id: 'person/me', kind: 'person', name: 'me', attrs: {}, involved: [] }] }, false);
ok('every body is a node, each ref attribute an edge, an involvement an edge, and a pair with one attribute one edge',
  g.nodes.some(function (n) { return n.id === 'person/me'; }) && g.edges.some(function (e) { return e.attr === 'involved' && e.from === 'person/me' && e.to === 'situation/2026-09-16-breakdown'; })
  && tiny.edges.length === 4 && tiny.byId['thing/x'].degree === 4 && tiny.edges.filter(function (e) { return e.attr === 'location'; }).length === 1);
const fam = render.graphOf({ me: 'person/me', bodies: [
  { id: 'person/me', kind: 'person', name: 'me', attrs: {}, involved: [] },
  { id: 'person/lin', kind: 'person', name: 'Lin', attrs: { relationship: { value: 'son', at: '2026-09-01T00:00:00Z' } }, involved: [] },
  { id: 'thing/lamp', kind: 'thing', name: 'lamp', attrs: {}, involved: [] }] }, false);
ok('a person\'s relationship to the owner is a line labelled with it, from the owner',
  fam.edges.length === 1 && fam.edges[0].from === 'person/me' && fam.edges[0].to === 'person/lin' && fam.edges[0].attr === 'son');
ok('a body with no line is off the diagram but found by name', !fam.nodes.some(function (n) { return n.id === 'thing/lamp'; })
  && fam.all.some(function (n) { return n.id === 'thing/lamp'; }) && !!fam.byId['thing/lamp'] && fam.nodes.length === 2);
ok('a closed situation is off the graph until past is asked for', !g.byId['situation/2026-09-01-preop'] && !!gp.byId['situation/2026-09-01-preop']);
const me = g.byId['person/me'];
ok('the pane names a body, its attributes and its connections, escaped', me && render.nodePane(me, g).includes('href="#body/person/me"') && render.nodePane(g.byId['thing/subaru'], g).includes('&lt;b&gt;Subaru&lt;/b&gt;') && !render.nodePane(g.byId['thing/subaru'], g).includes('<b>Subaru</b>'));
ok('an edge pane names both ends and the attribute', g.edges.length > 0 && render.edgePane(g.edges[0], g).includes('data-pick="' + g.edges[0].from + '"') && render.edgePane(g.edges[0], g).includes(g.edges[0].attr));
ok('a situation phase comes from its times, not a stored guess', render.phase({ attrs: { status: { value: 'under way' }, starts: { value: '2026-12-05T19:00:00Z' }, ends: { value: '2026-12-05T20:00:00Z' } } }, '2026-09-18T12:00:00Z') === 'upcoming'
  && render.phase({ attrs: { starts: { value: '2026-09-18T11:00:00Z' }, ends: { value: '2026-09-18T13:00:00Z' } } }, '2026-09-18T12:00:00Z') === 'under way'
  && render.phase({ attrs: { starts: { value: '2026-09-18T11:00:00Z' }, ends: { value: '2026-09-18T11:30:00Z' } } }, '2026-09-18T12:00:00Z') === 'over'
  && render.phase({ attrs: { status: { value: 'closed' }, ends: { value: '2099-01-01T00:00:00Z' } } }, '2026-09-18T12:00:00Z') === 'closed'
  && render.phase({ attrs: {} }, '2026-09-18T12:00:00Z') === 'open');

const body = render.body(view);
ok('the body view names the body', body.includes('the Subaru') && body.includes('thing/subaru'));
ok('a ref value is a link to that body', body.includes('href="#body/place/johns-machine-shop"'));
ok('the timeline shows every row with its status', body.includes('superseded') && body.includes('retracted') && body.includes('Route 9'));
ok('only a live row gets a retract button', (body.match(/data-retract="/g) || []).length === 1 && body.includes('data-retract="3-c"'));
ok('a source pointer is shown', body.includes('talon-dm') && body.includes('m3'));
ok('the retraction note is shown', body.includes('wrong car'));
ok('involved and actions are listed', body.includes('situation/2026-09-16-breakdown') && body.includes('Call the shop'));
const bodyWithState = render.body(Object.assign({}, view, { involved: ['situation/2026-09-16-breakdown', 'situation/2026-09-20-dinner'] }), state);
ok('involved situations are the same cards as the bodies page: named, with phase, id as subtext, soonest first',
  bodyWithState.includes('<h2>Involved in</h2><div class="bodies"><a href="#body/situation/2026-09-20-dinner">Dinner at eight <span class="muted">upcoming, 2099-09-20 23:00:00</span><span class="id">situation/2026-09-20-dinner</span></a>')
  && bodyWithState.includes('>breakdown <span class="muted">open</span><span class="id">situation/2026-09-16-breakdown</span></a></div>')
  && !bodyWithState.includes('</a>, <a'));
ok('without the state the involved cards are named by id, never a run of links', body.includes('<div class="bodies"><a href="#body/situation/2026-09-16-breakdown">situation/2026-09-16-breakdown') && !body.includes('</a>, <a'));
const sitView = render.body({ id: 'situation/2026-12-05-meeting', kind: 'situation', name: 'Parent meeting', aliases: [], ship: null, attrs: { starts: { value: '2099-12-05T19:00:00Z', at: '2026-09-18T00:00:00Z', by: 'talon', source: { kind: 'talon-dm', id: 'm1' }, obs: '9-a' }, ends: { value: '2099-12-05T20:00:00Z', at: '2026-09-18T00:00:00Z', by: 'talon', source: { kind: 'talon-dm', id: 'm1' }, obs: '9-b' } }, involved: [], actions: [], observations: [] });
ok('a situation view says upcoming with its schedule', sitView.includes('<p class="phase">upcoming') && sitView.includes('starts ') && sitView.includes('ends ') && !sitView.includes('ended '));

const inboxHtml = render.inbox(inbox);
ok('a proposed action offers approve and dismiss', inboxHtml.includes('data-move="p1:approved"') && inboxHtml.includes('data-move="p1:dismissed"') && !inboxHtml.includes('data-move="p1:done"'));
ok('an approved action offers done, failed and dismiss', inboxHtml.includes('data-move="a1:done"') && inboxHtml.includes('data-move="a1:failed"') && inboxHtml.includes('data-move="a1:dismissed"') && !inboxHtml.includes('data-move="a1:approved"'));
ok('a claimed action names its claimant and offers only dismiss', inboxHtml.includes('claimed by telegram') && inboxHtml.includes('data-move="c1:dismissed"') && !inboxHtml.includes('data-move="c1:done"') && !inboxHtml.includes('data-move="c1:claimed"'));
ok('about ids link to bodies', inboxHtml.includes('href="#body/person/sarah"'));
ok('about names the body when the state is at hand, with the id on hover, and falls back to the id',
  render.inbox(inbox, state).includes('about <a href="#body/thing/subaru" title="thing/subaru">the &lt;b&gt;Subaru&lt;/b&gt;</a>')
  && render.inbox(inbox, state).includes('<a href="#body/person/sarah" title="person/sarah">person/sarah</a>'));
ok('an empty inbox says so', render.inbox([]).includes('Nothing waiting'));
ok('a proposed action has a refine box and a button with its id', inboxHtml.includes('<input data-refine-text="p1" placeholder="a note for this action">') && inboxHtml.includes('<button data-refine="p1">refine</button>'));
ok('an approved or claimed action has no refine box', !inboxHtml.includes('data-refine="a1"') && !inboxHtml.includes('data-refine-text="a1"') && !inboxHtml.includes('data-refine="c1"'));
ok('the refine note is empty on render', inboxHtml.includes('<span class="muted" data-refine-note="p1"></span>'));
const kindsHtml = render.inbox([
  { id: 'n1', kind: 'note', title: 'A note', status: 'proposed', proposed: '2026-09-17T02:11:00Z', by: 'mcp', about: [], history: [] },
  { id: 'm1', kind: 'merge', title: 'Merge two', status: 'proposed', proposed: '2026-09-17T02:11:00Z', by: 'mcp', about: [], history: [] },
  { id: 't1', kind: 'task', title: 'A task', status: 'proposed', proposed: '2026-09-17T02:11:00Z', by: 'mcp', about: [], history: [] },
  { id: 'e1', kind: 'calendar', title: 'An event', status: 'proposed', proposed: '2026-09-17T02:11:00Z', by: 'mcp', about: [], history: [] },
]);
ok('only a proposed task, calendar event or message gets a refine box', kindsHtml.includes('data-refine="t1"') && kindsHtml.includes('data-refine="e1"') && !kindsHtml.includes('data-refine="n1"') && !kindsHtml.includes('data-refine="m1"') && kindsHtml.includes('data-move="n1:approved"'));

const settings = render.settings({ kinds: { person: { attrs: ['status'] } } }, { auto: ['task'], push: 'proposed', retention_days: 365, sensitive: ['health'] });
ok('the schema is editable JSON', settings.includes('id="schema"') && settings.includes('&quot;person&quot;'));
ok('the policy is editable JSON', settings.includes('id="policy"') && settings.includes('&quot;health&quot;'));

const keyRows = [
  { id: '2q2i2cl8', name: 'action generator', by: 'generator', scope: { kinds: ['person', 'situation'], actions: ['task', 'note'], write: false, sensitive: 'none' }, made: '2026-09-18T15:00:00Z', used: '2026-09-18T16:00:00Z' },
  { id: 'abc123', name: 'mail <b>reader</b>', by: 'mail', scope: { kinds: ['person'], actions: [], write: true, sensitive: 'write' }, made: '2026-09-17T10:00:00Z', used: null },
];
const keysHtml = render.keys(keyRows, { kinds: { person: {}, thing: {} }, actions: ['task', 'home'] });
ok('keys are listed newest first with name, identity, scope, made and last used', keysHtml.indexOf('action generator') < keysHtml.indexOf('mail &lt;b&gt;reader&lt;/b&gt;')
  && keysHtml.includes('<td data-label="writes as">generator</td>') && keysHtml.includes('person, situation \u00b7 actions task, note \u00b7 read-only')
  && keysHtml.includes('<td data-label="made">2026-09-18 15:00:00</td><td data-label="last used">2026-09-18 16:00:00</td>'));
ok('a key never used says never, a sensitive writer says so', keysHtml.includes('<span class="muted">never</span>') && keysHtml.includes('person \u00b7 no actions \u00b7 writes \u00b7 writes sensitive'));
ok('every key has a revoke button by id, named for the confirm', keysHtml.includes('data-revoke="2q2i2cl8" data-name="action generator"') && keysHtml.includes('data-revoke="abc123"'));
ok('the mint form offers the schema kinds, checked, and its action kinds, unchecked', keysHtml.includes('name="kinds" value="person" checked') && keysHtml.includes('name="kinds" value="thing" checked')
  && keysHtml.includes('name="actions" value="home">') && !keysHtml.includes('name="actions" value="message"'));
ok('no token is shown unless one was just minted', !keysHtml.includes('id="token"'));
const mintedHtml = render.keys(keyRows, { kinds: {} }, { id: 'n3w', name: 'phone', by: 'talon', token: 'n3w.s3cr3t<x>' });
ok('a minted token is shown once, escaped, with copy and dismiss', mintedHtml.includes('<code id="token">n3w.s3cr3t&lt;x&gt;</code>') && mintedHtml.includes('data-copy="token"') && mintedHtml.includes('data-dismiss-token'));
ok('every table has a head row and labels each cell with its column, for the stacked phone layout',
  body.includes('<table><thead><tr><th scope="col">attribute</th>') && body.includes('<td data-label="value"><a href="#body/place/johns-machine-shop"')
  && body.includes('<td data-label="at">2026-09-17 02:10:00</td>') && body.includes('<td data-label="">' + '<button class="danger" data-retract="3-c"')
  && (body.match(/<td(?![^>]*data-label=)/g) || []).length === 0 && (keysHtml.match(/<td(?![^>]*data-label=)/g) || []).length === 0);
ok('an empty key list says so and the form falls back to the five action kinds', render.keys([], { kinds: {} }).includes('No keys yet') && render.keys([], {}).includes('name="actions" value="calendar"'));
const hostile = render.inbox([{ id: 'h1', kind: 'task', title: 'Call <b>the</b> shop', status: 'proposed', proposed: '2026-09-17T02:10:00Z', by: '<i>who</i>', about: [], history: [] }]);
ok('titles and actors are escaped in the inbox', !hostile.includes('<b>the</b>') && hostile.includes('&lt;b&gt;the&lt;/b&gt;') && hostile.includes('&lt;i&gt;who&lt;/i&gt;'));
const hostileBody = render.body(Object.assign({}, view, { observations: [Object.assign({}, view.observations[2], { note: 'wrong <script>car</script>', by: '<x>' })] }));
ok('notes and actors are escaped on the timeline', !hostileBody.includes('<script>') && hostileBody.includes('&lt;script&gt;car&lt;/script&gt;') && hostileBody.includes('&lt;x&gt;'));
ok('esc handles the five characters', render.esc('<&>"\'') === '&lt;&amp;&gt;&quot;&#39;');
ok('fmtValue renders strings, refs and objects', render.fmtValue('x') === 'x' && render.fmtValue({ ref: 'a/b' }).includes('#body/a/b') && render.fmtValue({ n: 1 }) === '{&quot;n&quot;:1}');

const first = render.sseEvent('event: old /rev\ndata: 1789600000000');
ok('sseEvent reads the initial "old /rev" name and its data', first.name === 'old /rev' && first.data === '1789600000000' && render.sseEvent(': comment\n').name === '');
ok('route reads a body hash, and an empty hash is the body list', render.route('#body/person/me').name === 'body' && render.route('#body/person/me').id === 'person/me' && render.route('').name === 'bodies' && render.route('#inbox').name === 'inbox');
ok('seg encodes each segment and keeps the slash', render.seg('situation/2026-09-16 breakdown') === 'situation/2026-09-16%20breakdown');
const gen = { enabled: true, url: 'https://openrouter.ai/api/v1', model: 'moonshotai/kimi-k3', api_key_set: true, reasoning: { effort: 'high' }, max_tokens: 32000, max_actions: 5, timezone: '', cooldown_minutes: 60, max_daily: 24, max_urgent: 5 };
const genLast = { at: '2026-09-19T01:07:41Z', filed: 3, dropped: 1, skipped: false, notes: ['model note: the trip is stale'], usage: { cost: 0.0229, prompt_tokens: 6621, completion_tokens: 1404 }, seconds: 17, error: null, calls_today: 4, urgent_today: 1, month: '2026-09', spend_month_micro: 1234567 };
const genSettings = render.settings({ kinds: {} }, { auto: [] }, gen, genLast);
ok('the generator card shows the settings and says a key is set', genSettings.includes('<h2>Generator</h2>') && genSettings.includes('name="model" value="moonshotai/kimi-k3"') && genSettings.includes('a key is set'));
ok('the generator card offers a run and a save', genSettings.includes('data-generate="1"') && genSettings.includes('data-save-generator="1"'));
ok('the last pass is summarised', genSettings.includes('3 filed, 1 dropped') && genSettings.includes('$0.0229') && genSettings.includes('the trip is stale') && genSettings.includes('Model calls today: 4 (1 urgent)') && genSettings.includes('This month: $1.23'));
ok('the limits are on the card', genSettings.includes('name="cooldown_minutes" value="60"') && genSettings.includes('name="max_daily" value="24"') && genSettings.includes('name="max_urgent" value="5"'));
const travelSettings = render.settings({ kinds: {} }, {}, {}, {}, {}, {}, {}, {}, {}, {}, [], [], {}, {}, {}, {}, {}, {}, [], [], [], { enabled: true, token_set: true, lead_min: 10, buffer_min: 5, position_at: '2026-10-04T20:00:00Z' }, { next: { name: 'Parent meeting', starts: '2026-10-04T21:00:00Z', minutes: 32, leave_by: '2026-10-04T20:23:00Z' }, notes: ['told the owner to leave for Parent meeting'] });
ok('the time-to-leave card offers the token without showing one, says when the phone last spoke, and the next plan',
  travelSettings.includes('<h2>Time to leave</h2>') && travelSettings.includes('name="token" type="password" placeholder="a token is set; leave blank to keep it"')
  && travelSettings.includes('Your phone last said where you are') && travelSettings.includes('Next: Parent meeting') && travelSettings.includes('32 min with traffic')
  && travelSettings.includes('data-save-travel="1"'));
const whySettings = render.settings({ kinds: {} }, {}, {}, {}, {}, {}, {}, {}, {}, {}, [], [], {}, {}, {}, {}, {}, {}, [], [], [], { enabled: true, token_set: true },
  { next: { name: 'Chess', starts: '2026-10-05T21:00:00Z', leave_by: '2026-10-05T20:20:00Z', minutes: 31, typical_minutes: 19, via: 'I 95 South', incident: 'Crash on I-95 S', learned_min: 4 } });
ok('the next plan says why: the usual time, the roads, an incident, and what arrivals there taught (version 73)',
  whySettings.includes('31 min with traffic (19 usual) via I 95 South') && whySettings.includes('On the way: Crash on I-95 S') && whySettings.includes('Your arrivals there add 4 min to park.'));
const calmSettings = render.settings({ kinds: {} }, {}, {}, {}, {}, {}, {}, {}, {}, {}, [], [], {}, {}, {}, {}, {}, {}, [], [], [], { enabled: true },
  { next: { name: 'Chess', starts: '2026-10-05T21:00:00Z', leave_by: '2026-10-05T20:20:00Z', minutes: 20, typical_minutes: 19, via: '', incident: '', learned_min: 0 } });
ok('a drive near its usual time says no usual, no roads, no incident and nothing learned', calmSettings.includes('20 min with traffic, leave by') && !calmSettings.includes('usual') && !calmSettings.includes('On the way') && !calmSettings.includes('arrivals there'));
const mapSettings = render.settings({ kinds: {} }, {}, {}, {}, {}, {}, {}, {}, {}, {}, [], [], {}, {}, {}, { day: '2026-10-06', at: '2026-10-06T11:00:00Z', sent: true, tags: {}, notes: [], map: 'pin-l-1+d9534f(-89.5,39.6)' });
ok('the brief card shows the stops on a map when the brief had any', mapSettings.includes('<img class="brief-map"') && mapSettings.includes('/apps/orrery/api/brief/map?at=2026-10-06T11%3A00%3A00Z') && !whySettings.includes('brief-map'));
const weekSettings = render.settings({ kinds: {} }, {}, {}, {}, {}, {}, {}, {}, {}, {}, [], [], {}, {}, {}, {}, {}, {}, [], [], [], {}, {},
  { review: { at: '2026-10-11T22:00:00Z', sent: true, text: 'Your week, Sunday 2026-10-11\n\nWork\nMon 9 h' }, healthDays: 9, health: { day: '2026-10-10', steps: 4210, workouts: [{}] }, work: { day: '2026-10-11', active_minutes: 545 },
    nudge: { day: '2026-10-11', sent: [{ at: '2026-10-11T19:05:00Z', kind: 'desk', title: '1 h 35 min at the desk' }] },
    rhythm: { quiet_from: '22:00', quiet_to: '07:00', family_from: '', family_to: '', evening_from: '18:00', evening_to: '21:00', weekend_from: '09:00', weekend_to: '12:00', per_window: 2, young_age: 0, young_share: 100 } });
ok('the week card says what came in, how far the baseline is, and shows the last review (version 74)',
  weekSettings.includes('<h2>The week</h2>') && weekSettings.includes('Health: 9 days kept; the baseline needs 14.') && weekSettings.includes('4210 steps, 1 workout')
  && weekSettings.includes('9 h 5 min at the computer') && weekSettings.includes('data-review-wake="1"') && weekSettings.includes('Your week, Sunday 2026-10-11')
  && weekSettings.includes('Nudges on 2026-10-11: 1 of 3. Last: 1 h 35 min at the desk')
  && weekSettings.includes('name="quiet_from" value="22:00"') && weekSettings.includes('name="family_from" value=""') && weekSettings.includes('data-save-rhythm="1"'));
const outSettings = render.settings({ kinds: {} }, {}, {}, {}, {}, {}, {}, {}, {}, {}, [], [], {}, {}, {}, {}, {}, {}, [], [], [], {}, {},
  { outdoors: { weather: true, pota: true, pota_location: 'US-GT', pota_radius_km: 30 }, weather: { forecast_at: '2026-10-06T18:00:00Z', alerts: 1, note: '' }, parks: { at: '2026-10-06T18:01:00Z', near: 4, added: 2, note: '' } });
ok('the outdoors form shows the settings, the forecast and the parks (version 76)',
  outSettings.includes('name="weather" checked') && outSettings.includes('name="pota" checked') && outSettings.includes('name="pota_location" value="US-GT"') && outSettings.includes('name="pota_radius_km" value="30"')
  && outSettings.includes(', 1 alert.') && outSettings.includes(': 4 near, 2 new.') && outSettings.includes('data-save-outdoors="1"'));
ok('outdoors off by default but the weather, which no forecast yet says', weekSettings.includes('name="weather" checked') && !weekSettings.includes('name="pota" checked') && weekSettings.includes('No forecast yet.'));
const sphState = { bodies: [
    { id: 'sphere/the-llc', kind: 'sphere', name: 'The llc', attrs: { summary: { value: 'client work' } } },
    { id: 'situation/client-dinner', kind: 'situation', name: 'Client dinner', attrs: { sphere: [{ value: { ref: 'sphere/the-llc' }, by: 'owner' }] } },
    { id: 'activity/ballet', kind: 'activity', name: 'Ballet', attrs: { sphere: { value: { ref: 'sphere/home' }, by: 'owner' } } },
    { id: 'thing/car', kind: 'thing', name: 'Car', attrs: {} }],
  actions: [{ id: 'a1', kind: 'fact', status: 'proposed', title: 'File invoice under the-llc', payload: { attr: 'sphere', value: { ref: 'sphere/the-llc' } } }] };
const sph = render.spheres(sphState);
ok('the spheres page lists home first (made when the ship has none), what each holds and who filed it, and what waits (version 84)',
  sph.indexOf('<h2>Home</h2>') < sph.indexOf('<h2>The llc</h2>') && sph.includes('Ballet</a> <span class="muted">activity &middot; filed by owner')
  && sph.includes('And 1 more under no sphere.') && sph.includes('<p>client work</p>') && sph.includes('Client dinner</a>')
  && sph.includes('1 waiting for you</a>: File invoice under the-llc'));
ok('a route to the spheres page is its own view', render.route('#spheres').name === 'spheres');
ok('a twin reads as the body on the other ship (version 89)', render.fmtValue({ ship: '~zod', id: 'person/lena' }) === 'person/lena on ~zod');
const pairHtml = render.pairingCard([{ key: '~zod|sphere/home', host: '~zod', sphere: 'sphere/home', there: 'person/rowan', there_name: 'Rowan', here: 'person/kid', here_name: 'Rowan', why: 'name' }]);
ok('the pairing card asks whether a name match is the same, with both answers (version 91)',
  pairHtml.includes('To pair') && pairHtml.includes('Rowan <span class="muted">on ~zod</span>') && pairHtml.includes('href="#body/person/kid"')
  && pairHtml.includes('data-pair-key="~zod|sphere/home" data-pair-there="person/rowan" data-pair-same="1"') && pairHtml.includes('data-pair-same="0"'));
ok('with nothing to pair, the card is empty', render.pairingCard([]) === '<div id="pairing-card"></div>');
ok('a row from another ship names the person carrying it, marked as theirs (version 93)',
  render.byWho('~zod', { bodies: [{ id: 'person/sam', name: 'Sam', ship: '~zod' }] }) === '<span class="peer" title="from ~zod">Sam</span>'
  && render.byWho('~nec', { bodies: [] }) === '<span class="peer" title="from ~nec">~nec</span>' && render.byWho('owner', {}) === 'owner');
// the sharing page and card (version 95)
const shState = { bodies: [
  { id: 'person/sam', kind: 'person', name: 'Sam', ship: '~zod' }, { id: 'person/gran', kind: 'person', name: 'Gran' },
  { id: 'sphere/home', kind: 'sphere', name: 'Home' }, { id: 'sphere/sail', kind: 'sphere', name: 'Sailing' },
  { id: 'thing/boat', kind: 'thing', name: 'Boat' }, { id: 'situation/party', kind: 'situation', name: 'Party' }] };
const shShares = {
  sphere_shares: { 'sphere/home': { '~zod': 'edit' }, 'sphere/sail': { '~nec': 'edit' } },
  sphere_follows: { '~zod|sphere/home': { role: 'host', host: '~zod', sphere: 'sphere/home', local: 'sphere/home', last: '2026-10-08T12:00:00Z', error: '' },
    '~nec|sphere/sail': { role: 'peer', host: '~nec', sphere: 'sphere/sail', local: 'sphere/sail', mode: 'edit', last: '2026-10-08T12:00:00Z', error: 'the feed could not be read', pending: [{}] } },
  sphere_offers: { '~nec|sphere/garden': { host: '~nec', sphere: 'sphere/garden', name: 'Garden', mode: 'read' } },
  offers: { '~zod/thing/kayak': { host: '~zod', id: 'thing/kayak', name: 'Kayak', mode: 'edit' } },
  shares: { 'thing/boat': { '~zod': 'read' } },
  accepted: { '~nec/person/me': { host: '~nec', id: 'person/me', target: 'person/nec', mode: 'read', last: '', error: '' } },
  situation_shares: { 'situation/party': { 'person/gran': { digest: 'x', via: 'mail' }, 'person/sam': { ship: '~zod' } } } };
const shHtml = render.sharing(shState, shShares, {}, [], { peer_push: 'all' }, { ids: ['r1', 'r2'] });
ok('the sharing page offers what waits: a sphere and a body, each to accept or decline',
  shHtml.includes('The sphere <strong>Garden</strong> from ~nec') && shHtml.includes('data-accept-sphere="1" data-host="~nec" data-sphere="sphere/garden"')
  && shHtml.includes('data-decline-sphere="1"') && shHtml.includes('<strong>Kayak</strong>') && shHtml.includes('data-accept-body="1" data-host="~zod" data-id="thing/kayak"'));
ok('spheres you share, with whom, their edits read, a stop; the feed kept back for a host is not listed as yours',
  shHtml.includes('data-unshare-sphere="sphere/home" data-ship="~zod"') && shHtml.includes("their edits: last read") && !shHtml.includes('data-unshare-sphere="sphere/sail"')
  && shHtml.includes('data-share-sphere="1"') && shHtml.includes('class="picker"') && shHtml.includes('<input type="hidden" name="ship" value="">'));
ok('spheres shared with you: from whom, the error, what waits to pair, read now and leave',
  shHtml.includes('the feed could not be read') && shHtml.includes('1 to pair') && shHtml.includes('data-sphere-leave="1" data-host="~nec" data-sphere="sphere/sail"') && shHtml.includes('data-sync="1"'));
ok('bodies shared alone, both ways, situations by how each person is reached, the pushes and the count kept back',
  shHtml.includes('data-unshare-body="thing/boat" data-ship="~zod"') && shHtml.includes('data-leave-body="1" data-host="~nec" data-id="person/me"')
  && shHtml.includes('invited by email') && shHtml.includes('on their orrery') && shHtml.includes('value="all" checked') && shHtml.includes('2 rows are kept to yourself'));
const viaSit = render.sharing(shState, Object.assign({}, shShares, { shares: { 'situation/party': { '~zod': 'edit' } } }), {}, [], {}, {});
ok("a situation's own share is not stopped from the bodies list: the next pass would share it again",
  viaSit.includes("through the situation's shared-with") && !viaSit.includes('data-unshare-body="situation/party"'));
ok('the sphere form chooses nothing by itself, and says what home shares', shHtml.includes('<option value="">choose a sphere</option>') && shHtml.includes('Home (every body filed under none)'));
const sphCard = render.bodySharingCard({ id: 'sphere/home', kind: 'sphere', attrs: {} }, shState, shShares, {});
ok("a sphere's card shares the whole sphere", sphCard.includes('This sphere is shared with Sam') && sphCard.includes('<input type="hidden" name="sphere" value="sphere/home">'));
const boatCard = render.bodySharingCard({ id: 'thing/boat', kind: 'thing', attrs: { likes: { value: 'wax', by: 'owner', obs: 'r1' }, note: { value: 'x', by: '~zod', obs: 'r9' } } }, shState, shShares, { ids: ['r1'] });
ok("a body's card: who it is shared with alone, the form, and in a shared sphere its own rows to keep back (another ship's not)",
  boatCard.includes('Shared alone with Sam') && boatCard.includes('data-share-body="thing/boat"') && boatCard.includes('data-private="r1" data-keep="0"') && boatCard.includes('share it') && !boatCard.includes('r9'));
const partyCard = render.bodySharingCard({ id: 'situation/party', kind: 'situation', attrs: { 'shared-with': [{ value: { ref: 'person/gran' }, obs: 'w1' }] } }, shState, shShares, {});
ok("a situation's card: who it is shared with alone and how, remove, and add anyone",
  partyCard.includes('Shared with, just this situation') && partyCard.includes('invited by email') && partyCard.includes('data-unshare-situation="w1"') && partyCard.includes('data-share-situation="situation/party"'));
const notShared = render.bodySharingCard({ id: 'thing/boat', kind: 'thing', attrs: { sphere: { value: { ref: 'sphere/work' } }, likes: { value: 'wax', by: 'owner', obs: 'r1' } } }, shState, shShares, {});
ok('a body filed only in a sphere not shared offers nothing to keep back', !notShared.includes('data-private'));
ok('the Inbox says whose an action is: for someone, or from another ship for you',
  render.forWhom({ status: 'approved', payload: { assignee: { ref: 'person/sam' } } }, shState).includes('for Sam') && render.forWhom({ status: 'approved', payload: { assignee: { ref: 'person/sam' } } }, shState).includes('open here until they finish it')
  && render.forWhom({ payload: { twin: { ship: '~zod', id: 'a1' }, assignee: { ref: 'person/me' } } }, shState).includes('from Sam, for you') && render.forWhom({ payload: {} }, shState) === '');
ok('a proposed task can be assigned to anyone, those with orrery marked, the one assigned shown',
  render.assignBox({ id: 'a1', payload: { assignee: { ref: 'person/sam' } } }, shState).includes('value="Sam (their orrery)"') && render.assignBox({ id: 'a1', payload: { assignee: { ref: 'person/sam' } } }, shState).includes('name="assign-who" value="person/sam"'));
// the person picker: found as typed, by name, nickname, ship or id, close first
const pk = [{ v: 'person/sam', t: 'Samantha Lee', s: '~zod', a: ['Sam', 'mom'], id: 'person/sam' }, { v: 'person/gran', t: 'Granny Rose', s: '', a: ['nana'], id: 'person/gran' },
  { v: 'person/simon', t: 'Simon', s: '~nec', a: [], id: 'person/simon' }];
const names = q => render.pickMatches(pk, q).map(d => d.t);
ok('the picker finds by name, a word\'s start, a nickname, a ship, and letters in order, close matches first',
  names('sam')[0] === 'Samantha Lee' && names('rose')[0] === 'Granny Rose' && names('nana')[0] === 'Granny Rose' && names('~nec')[0] === 'Simon'
  && names('zod')[0] === 'Samantha Lee' && names('smn').indexOf('Simon') >= 0 && names('xyz').length === 0, [names('sam'), names('smn')]);
ok('an empty box lists everyone, by name, the blank choice first', render.pickMatches([{ v: '', t: 'me', s: '', a: [], id: '' }].concat(pk), '').map(d => d.t).join('|') === 'me|Granny Rose|Samantha Lee|Simon');
ok('the list says how each was found, and no one when no one is', render.pickList(pk, 'mom').includes('data-pick="person/sam"') && render.pickList(pk, 'mom').includes('~zod &middot; Sam &middot; mom') && render.pickList(pk, 'qqq').includes('no one by that'));
ok('a picker carries its people and the field it fills, in phrasing markup a <p> keeps whole', render.personPicker('who', [{ id: 'person/sam', name: 'Sam', ship: '~zod', aliases: ['Sammy'] }]).includes('name="who"')
  && !/<(ul|li|div|p)\b/.test(render.personPicker('who', [{ id: 'person/sam', name: 'Sam' }]) + render.pickList(pk, 'sam') + render.pickList(pk, 'qqq'))
  && render.personPicker('ship', [{ id: 'person/sam', name: 'Sam', ship: '~zod' }], { ships: true }).includes('&quot;v&quot;:&quot;~zod&quot;'));
// the inbox: names for what an action names, the id when there is none
const byIdSh = { 'person/sam': { id: 'person/sam', name: 'Sam' }, 'thing/boat': { id: 'thing/boat', name: 'The boat' } };
const pl = render.payloadLine({ assignee: { ref: 'person/sam' }, subject: 'thing/boat', value: 'sphere/unknown-x', text: 'wax it', twin: { ship: '~zod', id: 'a1' } }, byIdSh);
ok('the inbox names the bodies an action names, links them, keeps an unknown id, and leaves the twin to the from label',
  pl.includes('>Sam</a>') && pl.includes('>The boat</a>') && pl.includes('sphere/unknown-x') && pl.includes('wax it') && !pl.includes('twin'), pl);
const tt = render.namedText('Merge person/sam into person/sam-2 <b>', byIdSh);
ok('a title reads by name, keeps an id it has no name for, and stays escaped', tt === 'Merge Sam into person/sam-2 &lt;b&gt;', tt);
const locHtml = render.locationCard({ out: [{ ship: '~sampel', until: '2026-10-08T22:00:00Z', home: true, exact: false }], in: [{ ship: '~zod', name: 'Lena', km_from_home: 3, at: '2026-10-08T20:00:00Z' }],
  peers: [{ id: 'person/lena', name: 'Lena', ship: '~zod' }, { id: 'person/sam', name: 'Sam', ship: '~sampel' }] });
ok('the location card says who you share with and until when, who shares with you and how far, and offers the people with a ship (version 88)',
  locHtml.includes('Sharing with Sam until') && locHtml.includes('or until you are home') && locHtml.includes('to about a kilometre') && locHtml.includes('data-loc-stop="~sampel"')
  && locHtml.includes('Lena is sharing: 3 km from home') && locHtml.includes('<option value="~zod">Lena</option>') && locHtml.includes('data-loc-share="1"'));
ok('with no one to share with, the card says so', render.locationCard({}).includes('No one here has a ship to share with yet.'));
const weekEmpty = render.settings({ kinds: {} }, {}, {}, {}, {}, {}, {}, {}, {}, {}, [], [], {}, {}, {}, {}, {}, {}, [], [], [], {}, {}, {});
ok('an empty week card says nothing has come in', weekEmpty.includes('Health: nothing from your phone yet.') && weekEmpty.includes('Work: nothing from your computer yet.') && !weekEmpty.includes('Last review') && weekEmpty.includes('Nudges today: none yet.'));
const genOff = render.settings({ kinds: {} }, {}, { enabled: false, api_key_set: false, reasoning: { enabled: false } }, {});
ok('an untouched generator renders off, with no key and reasoning off', genOff.includes('name="enabled">') && genOff.includes('no key set') && genOff.includes('name="effort" value="off"'));
ok('the schema and policy cards still follow', genSettings.indexOf('<h2>Generator</h2>') < genSettings.indexOf('<h2>schema.json</h2>') && genSettings.includes('id="policy"'));
const recSettings = render.settings({ kinds: {} }, {}, gen, genLast, { at: '2026-09-20T01:00:00Z', times: 2, activities: ['activity/ballet'], people_made: 1, participants: 3, proposed: 1, merged: 0, retired: 20, pruned: 0 });
ok('the reconcile card follows the generator with a run button and the last run', recSettings.indexOf('<h2>Generator</h2>') < recSettings.indexOf('<h2>Reconcile</h2>') && recSettings.indexOf('<h2>Reconcile</h2>') < recSettings.indexOf('<h2>schema.json</h2>')
  && recSettings.includes('data-reconcile="1"') && recSettings.includes('1 activity (activity/ballet)') && recSettings.includes('20 retired'));
ok('a reconcile that never ran shows the card without a last line', !render.settings({ kinds: {} }, {}, gen, genLast, {}).includes('Last run'));
const tg = { enabled: true, token_set: true, secret_set: false, api_url: 'https://api.telegram.org', public_url: 'https://ship.example', model: 'deepseek/deepseek-v4-flash', max_tokens: 4000, chats: ['1001'], people: { '1001': 'person/me' }, gate: 30, escalate: 60, max_daily_messages: 500 };
const tgLast = { at: '2026-09-20T13:00:00Z', update_id: 7, chat: '1001', from: '1001', outcome: 'facts', notes: ['gate: 90, read', 'escalate: 12'], day: '2026-09-20', read_today: 3 };
const tgSettings = render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast);
const chat = { enabled: true, dms: ['~sampel-palnet'], channels: [], people: { '~sampel-palnet': 'person/sam' }, read_own: false, poll_minutes: 5, backfill_hours: 24, gate: 30, escalate: 60, max_daily_messages: 500, model: 'deepseek/deepseek-v4-flash' };
const chatLast = { since: '2026-09-21T22:00:00Z', at: '2026-09-22T22:07:08Z', read: 2, filed: 3, strangers: 1, held: 0, read_today: 2, day: '2026-09-22', notes: ['chat changes: null'], down: null };
const chatSettings = render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, {}, chat, chatLast, { items: [{ id: '~sampel-palnet', name: 'Sam' }, { id: '~zod', name: '' }], note: '' }, { items: [], note: 'groups desk not installed' });
ok('the chat card follows telegram with the picked DM listed by its nickname and a picker for more', chatSettings.indexOf('<h2>Telegram</h2>') < chatSettings.indexOf('<h2>Chat</h2>') && chatSettings.includes('<ul class="picked" data-picked="dms"><li data-id="~sampel-palnet">Sam <small class="muted">~sampel-palnet</small>') && chatSettings.includes('name="dms-find"') && chatSettings.includes('data-picked="channels"><li class="muted" data-empty="1">none picked</li>') && chatSettings.includes('groups desk not installed'));
ok('the chat card carries the people map, the switches and the buttons', chatSettings.includes('person/sam') && chatSettings.includes('name="read_own"') && chatSettings.includes('data-save-chat="1"') && chatSettings.includes('data-chat-wake="1"'));
ok('the chat card shows the last pass and its note, and the channel note when there are none', chatSettings.includes('read 2, filed 3, strangers 1') && chatSettings.includes('chat changes: null') && chatSettings.includes('groups desk not installed') && chatSettings.includes('Read today: 2'));
ok('a chat reader that never ran shows the card without a last line', !render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, {}, {}, {}, {}, {}).includes('strangers '));
const chatDown = render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, {}, chat, { at: '2026-09-22T22:07:08Z', since: '2026-09-22T21:00:00Z', down: { at: '2026-09-22T22:07:08Z', notes: ['model: 502'] } }, {}, {});
ok('a model down on the chat card is said in red with its note', chatDown.includes('The model could not be read') && chatDown.includes('model: 502'));
ok('the telegram card follows reconcile and says a token is set and no secret', tgSettings.indexOf('<h2>Reconcile</h2>') < tgSettings.indexOf('<h2>Telegram</h2>') && tgSettings.includes('a token is set') && tgSettings.includes('no secret set'));
ok('the card holds chats, people, thresholds and the cap', tgSettings.includes('name="chats" value="1001"') && tgSettings.includes('&quot;1001&quot;: &quot;person/me&quot;') && tgSettings.includes('name="gate" value="30"') && tgSettings.includes('name="max_daily_messages" value="500"'));
ok('the card asks Telegram what it holds', tgSettings.includes('data-webhook-info="1"') && tgSettings.includes('id="webhook-info"'));
ok('the card offers save and register', tgSettings.includes('data-save-telegram="1"') && tgSettings.includes('data-webhook="1"'));
ok('the card offers to make a secret', tgSettings.includes('data-make-secret="1"'));
ok('the last update is summarised', tgSettings.includes('Last update 7') && tgSettings.includes('facts') && tgSettings.includes('Read today: 3') && tgSettings.includes('gate: 90, read'));
ok('a kept update is shown with its notes and a wake button', render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, { update_id: 5, at: '2026-09-21T01:00:00Z', outcome: 'facts', down: { update_id: 9, at: '2026-09-21T02:00:00Z', notes: ['model: 404 no endpoints'] } }).includes('Update 9 is waiting since') && render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, { update_id: 5, at: '2026-09-21T01:00:00Z', outcome: 'facts', down: { update_id: 9, at: '2026-09-21T02:00:00Z', notes: ['model: 404 no endpoints'] } }).includes('model: 404 no endpoints') && render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, { down: { update_id: 9, at: '2026-09-21T02:00:00Z', notes: ['model: 404 no endpoints'] } }).includes('data-wake="1"'));
ok('a reader that never ran shows the card without a last line', !render.settings({ kinds: {} }, {}, gen, genLast, {}, { enabled: false }, {}).includes('Last update'));
const execLast = { at: '2026-09-21T06:31:59Z', acted_at: '2026-09-21T06:29:33Z', claimed: 2, sent: 1, placed: 1, failed: [{ id: '1789968868-c90fc464', title: 'Tell <b>Sarah</b> the tow is booked', note: 'person/sarah has no telegram attribute' }], ticked: 0, deleted: 1, moved: 0, closed: 1, adopted: 1, missing: ['auspex'], notes: ['an action waits: the calendar road is refused: veto'] };
const execSettings = render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, execLast);
ok('the executor card sits between reconcile and telegram with a wake button and no settings', execSettings.indexOf('<h2>Reconcile</h2>') < execSettings.indexOf('<h2>Executor</h2>') && execSettings.indexOf('<h2>Executor</h2>') < execSettings.indexOf('<h2>Telegram</h2>')
  && execSettings.includes('data-exec-wake="1"') && !execSettings.includes('data-save-executor'));
ok('the last pass is summarised with its counts, its failures with their notes, the missing desk and the notes', execSettings.includes('Last looked 2026-09-21 06:31:59.') && execSettings.includes('Last acted 2026-09-21 06:29:33: 2 claimed, 1 sent, 1 placed, 0 todos ticked, 1 deleted, 0 moved, 1 tasks closed from the calendar, 1 todos adopted.')
  && execSettings.includes('failed: Tell &lt;b&gt;Sarah&lt;/b&gt; the tow is booked <span class="muted">person/sarah has no telegram attribute</span>') && !execSettings.includes('<b>Sarah</b>')
  && execSettings.includes('The auspex desk is not installed') && execSettings.includes('the calendar road is refused: veto'));
ok('an executor that never ran shows the card without a last line, and one that only looked says nothing was done', !render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, {}).includes('Last looked')
  && render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, { at: '2026-09-21T06:31:59Z', acted_at: null, missing: [], notes: [] }).includes('Last looked 2026-09-21 06:31:59. Nothing done yet.'));
const calLast = { at: '2026-09-23T14:10:35Z', acted_at: '2026-09-23T14:10:35Z', events: 12, made: 1, rows: 5, cancelled: 0 };
const calSettings = render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, execLast, {}, {}, {}, {}, calLast);
ok('the executor card says what the calendar events reader did',
  calSettings.includes('Calendar events read 2026-09-23 14:10:35: 12 on the calendar. Last written 2026-09-23 14:10:35: 1 bodies made, 5 facts, 0 cancelled.')
  && !execSettings.includes('Calendar events read'));
const mailSettings = render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, execLast, {}, {}, {}, {}, calLast, { enabled: true, poll_minutes: 10, model: 'x/y' },
  { at: '2026-09-23T14:10:35Z', since: '2026-09-23T13:10:35Z', conversations: 2, changed: 3, read: 2, filed: 4, strangers: 1, held: 0, read_today: 2, notes: ['A1: approved'] },
  { day: '2026-09-23', at: '2026-09-23T11:00:05Z', sent: true, tags: { A1: 'x', A2: 'y' }, notes: [] });
ok('the mail card carries the reader\'s settings and its last pass, and the brief card the last brief sent',
  mailSettings.includes('<h2>Mail</h2>') && mailSettings.includes('name="enabled" checked') && mailSettings.includes('value="x/y"') && mailSettings.includes('2 threads, 3 messages; read 2, filed 4, strangers 1, held 0. Read today: 2.')
  && mailSettings.includes('A1: approved') && mailSettings.includes('data-mail-wake="1"') && mailSettings.includes('<h2>Daily brief</h2>') && mailSettings.includes('Last brief for 2026-09-23 at 2026-09-23 11:00:05, sent; 2 actions tagged.') && mailSettings.includes('data-brief-wake="1"'));
const readSettings = render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, execLast, {}, {}, {}, {}, calLast, {}, {}, {}, { enabled: true, model: 'x/y' }, { at: '2026-09-24T20:00:00Z', read: 1, filed: 4, read_today: 3, notes: ['1790000000000-0xab: The tow'] });
ok('the read card carries its settings and last read, between mail and the brief', readSettings.includes('<h2>Read</h2>') && readSettings.indexOf('<h2>Mail</h2>') < readSettings.indexOf('<h2>Read</h2>') && readSettings.indexOf('<h2>Read</h2>') < readSettings.indexOf('<h2>Daily brief</h2>')
  && readSettings.includes('data-save-read="1"') && readSettings.includes('Last read at 2026-09-24 20:00:00: read 1, filed 4. Read today: 3.') && readSettings.includes('1790000000000-0xab: The tow'));
const src = require('fs').readFileSync(require('path').join(__dirname, '..', 'code', 'nex', 'orrery', 'orrery.js'), 'utf8');
const payloadHtml = render.inbox([{ id: 'a1', kind: 'message', title: 'Wish Sarah happy birthday', status: 'proposed', proposed: '2026-09-20T10:00:00Z', by: 'generator', about: [], payload: { via: 'chat', to: 'person/sarah', text: 'Happy <b>birthday</b>', why: 'it is today' } }], state);
ok('the inbox shows what an action will do, escaped, the recipient linked, the why left out', payloadHtml.includes('class="payload"') && payloadHtml.includes('>via</span> chat') && payloadHtml.includes('Happy &lt;b&gt;birthday&lt;/b&gt;') && !payloadHtml.includes('<b>birthday</b>') && payloadHtml.includes('href="#body/person/sarah"') && !payloadHtml.includes('it is today'));
const libVersion = parseInt((require('fs').readFileSync(require('path').join(__dirname, '..', 'code', 'lib', 'orrery.hoon'), 'utf8').match(/\n\+\+  version  (\d+)\n/) || [])[1], 10);
const jsonVersion = JSON.parse(require('fs').readFileSync(require('path').join(__dirname, '..', 'code', 'version.json'), 'utf8')).version;
ok('the lib\'s version is the desk\'s', libVersion === jsonVersion, [libVersion, jsonVersion]);
ok('each view is one request: the settings page reads /settings, the chat lists in it; the inbox reads the state',
  src.includes("if (v.name === 'settings') return api('/settings');") && src.includes("var l = d.chat_lists || {};")
  && src.includes("if (v.name === 'inbox') return show(inbox(openActions(d), d));") && !src.includes("api('/actions?status=open')")
  && !src.includes("api('/chat/lists')"));
ok('a view seen before draws at once, even while another answer is out, except the two whose forms save whole documents',
  src.includes("cached: name !== 'settings' && name !== 'keys'") && src.includes("if (v.here === drawn || !v.cached || !seen[v.here]) return;")
  && src.includes("if (refreshing) { again = true; drawSeen(v); return; }"));
ok('an answer that lands after the owner moved to another view is kept, not drawn over it',
  src.includes("seen[v.here] = d;") && src.indexOf("if (viewNow().here !== v.here || again) { if (!held) { say(pending); pending = ''; } return; }") > src.indexOf("seen[v.here] = d;"));
ok('the state is asked for only if it moved: the page names its rev, and "same" keeps what it holds, drawn once',
  src.includes("var rev = had && typeof had.rev === 'number' ? '?rev=' + had.rev : '';") && src.includes("return api('/state' + rev).then(function (s) { return s && s.same ? had : s; });")
  && src.includes('var again = seen[v.here] === d && drawn === v.here;')
  && src.indexOf('var again = seen[v.here] === d && drawn === v.here;') < src.indexOf("seen['bodies '] = s; seen['inbox '] = s;"));
const tidyState = { me: 'person/me', bodies: [
  { id: 'person/me', kind: 'person', name: 'jackson', ship: '~zod', aliases: ['~bus'], attrs: { home: { value: { ref: 'place/home' } } } },
  { id: 'person/lena', kind: 'person', name: 'Lena', ship: '~wet', aliases: [], attrs: { relationship: { value: 'wife' } } },
  { id: 'person/martyr', kind: 'person', name: 'jackson wife', aliases: ['~wet', '~bus'], attrs: {} },
  { id: 'place/home', kind: 'place', name: 'Home', aliases: [], attrs: {} },
  { id: 'org/lone', kind: 'org', name: 'Lone <Co>', aliases: [], attrs: { phone: { value: '1' } } }] };
const dupes = render.dupesOf(tidyState);
const sits = render.dupesOf({ bodies: [
  { id: 'situation/a', kind: 'situation', name: 'Ballet', attrs: { starts: { value: '2026-10-01T18:00:00Z' } } },
  { id: 'situation/b', kind: 'situation', name: 'Ballet', attrs: { starts: { value: '2026-10-08T18:00:00Z' } } },
  { id: 'situation/c', kind: 'situation', name: 'ballet', attrs: { starts: { value: '2026-10-08T19:00:00Z' } } }] });
ok('likely duplicates: a shared own ship, the surer body as into, no weaker match beside a sure one, the owner never merged away; a situation by name only on the same day',
  dupes.length === 1 && dupes[0].from.id === 'person/martyr' && dupes[0].into.id === 'person/lena' && dupes[0].strong
  && !dupes.some(function (d) { return d.from.id === 'person/me' || d.into.id === 'person/me'; })
  && sits.length === 1 && sits.every(function (d) { return d.from.id !== 'situation/a' && d.into.id !== 'situation/a'; }));
const merged = render.dupesOf({ me: 'person/me', bodies: [
  { id: 'person/me', kind: 'person', name: 'jackson', ship: '~zod', aliases: ['~bus'], attrs: {} },
  { id: 'person/lena', kind: 'person', name: 'Lena', ship: '~wet', aliases: ['~bus', 'jackson'], attrs: {} }] });
ok('the owner is offered as into only on a ship the other holds as its own, not on an alias a merge brought', merged.length === 0);
const tidy = render.tidyCard(tidyState, false);
ok('the tidy section offers each duplicate a merge and each body with no connection a delete, names escaped',
  tidy.includes('data-merge="person/martyr" data-into="person/lena"') && tidy.includes('data-delete-body="org/lone"') && tidy.includes('Lone &lt;Co&gt;')
  && !tidy.includes('data-delete-body="person/me"') && !tidy.includes('data-delete-body="place/home"') && tidy.includes('1 possible duplicate, 2 with no connection'));
const prefs = render.prefsCard({ style: 'No em dashes.', preferences: ['Never a todo for attending'] }, [{ reason: 'never a todo for attending', count: 3 }, { reason: 'a refund, not a bill', count: 2 }]);
ok('the preferences card holds the style and one preference a line, and offers each reason not kept already',
  prefs.includes('No em dashes.</textarea>') && prefs.includes('Never a todo for attending</textarea>') && prefs.includes('data-prefer="a refund, not a bill"')
  && !prefs.includes('data-prefer="never a todo for attending"') && prefs.includes('2 times'));
// later itself, run: .then(later) hands it the ship's answer, which once
// became the bodies to wait for and threw in every refresh after
const laterSrc = (src.match(/function later\(gone\) \{[^\n]*\}/) || [''])[0];
const lat = new Function('typedNote', 'refresh', 'setTimeout',
  'var dirty, awaitMove, awaitGone; ' + laterSrc + '; later({ ok: true, id: "a1" }); var r = [awaitMove, awaitGone]; later(["person/x"]); return r.concat([awaitMove, awaitGone]);')(
  function () { return false; }, function () {}, function () {});
ok('an answer handed in by .then is not taken for bodies to wait for; a list is', lat[0] === 10 && lat[1] === null && lat[2] === 20 && lat[3][0] === 'person/x');
const aliased = render.body({ id: 'person/lena', kind: 'person', name: 'Lena', aliases: ['jack<son>'], attrs: {}, observations: [] }, { bodies: [], actions: [] });
ok('a body page gives each alias its own remove button, escaped', aliased.includes('data-unalias="jack&lt;son&gt;" data-id="person/lena"') && !aliased.includes('<son>'));
ok('after the owner\'s own move the refresh looks again each second until the rev moves, ten times at most',
  src.includes("function later(gone) { dirty = typedNote(); awaitGone = Array.isArray(gone) ? gone : null; awaitMove = awaitGone ? 20 : 10; setTimeout(function () { refresh(!dirty); }, 300); }")
  && src.includes("var still = awaitGone ? (s.bodies || []).some(function (x) { return awaitGone.indexOf(x.id) >= 0; }) : s.rev === before;")
  && src.includes("tidyGone[b.dataset.merge] = true; settled(b, 'merged'); later([b.dataset.merge]);"));
const goneTidy = render.tidyCard(tidyState, false, { 'person/martyr': true, 'org/lone': true });
ok('what the owner merged or deleted from the page stays out of the tidy list, whatever a refresh brings back',
  !goneTidy.includes('data-merge="person/martyr"') && !goneTidy.includes('data-delete-body="org/lone"'));
ok('a tidy move shows at once: the button says what is under way, and the row is struck through once the ship takes it',
  src.includes("working(b, 'merging');") && src.includes("settled(b, 'merged'); later([b.dataset.merge]);") && src.includes("function settled(b, what) {"));
const quality = render.qualityCard([{ by: 'mail', kind: 'task', kept: 3, dismissed: 1, reasoned: 1, waiting: 0, failed: 0 }]);
ok('the quality card says what each proposer kept of what was decided', quality.includes('>mail<') && quality.includes('75%') && quality.includes('(1 with a reason)') && render.qualityCard([]) === '');
const struck = render.correctionsCard([{ id: '42', subject: 'person/lena', attr: 'participants', value: 'situation/barcelona', why: 'she was not there', at: '2026-09-27T00:00:00Z', by: 'owner' }]);
ok('the corrections card lists what was struck, with the reason and an undo by id',
  struck.includes('href="#body/person/lena"') && struck.includes('she was not there') && struck.includes('data-uncorrect="42"') && render.correctionsCard([]) === '');
ok('a string or a ref value may be struck as not true; a number or a list may not',
  render.notTrue('person/lena', 'city', 'Paris').includes('data-correct="person/lena" data-attr="city" data-value="Paris"')
  && render.notTrue('person/lena', 'spouse', { ref: 'person/sam' }).includes('data-value="person/sam"')
  && render.notTrue('person/lena', 'age', 40) === '' && render.notTrue('person/lena', 'kids', ['a']) === '');
const box = render.instructBox('person/lena', '', 'Tell the ship');
ok('an instruction box carries its body and action in one key, with a do-it and a propose button',
  box.includes('data-instruct-text="person/lena|"') && box.includes('data-instruct="person/lena|">do it') && box.includes('data-propose="1">propose'));
ok('the body page offers an instruction box and marks each string value not true',
  body.includes('data-instruct-text="' + view.id + '|"') && body.includes('data-correct="'));
ok('the inbox leads with an instruction box and answers a proposed note with one of its own, not a refine box',
  inboxHtml.indexOf('data-instruct-text="|"') < inboxHtml.indexOf('<ul class="actions">')
  && render.inbox([{ id: 'n9', kind: 'note', title: 'Lena in Barcelona?', status: 'proposed', proposed: '', by: 'generator', about: [], history: [] }]).includes('data-instruct-text="|n9"')
  && !inboxHtml.includes('data-instruct-text="|p1"'));
ok('a half-typed instruction holds the refresh like a half-typed refine note',
  src.includes("querySelectorAll('[data-refine-text], [data-instruct-text]')"));
const withCals = render.settings({ kinds: {} }, { todo_calendar: 'c-lists' }, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, [], []);
ok('the settings page shows what was struck, after the preferences',
  render.settings({ kinds: {} }, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, {}, [], [], [{ id: '1', subject: 'person/a', attr: 'x', value: 'y', why: '', at: '', by: 'owner' }]).includes('Struck as wrong'));
ok('the executor card lets the owner pick the lists, says todos stay on the ship, and the settings page leads with preferences',
  withCals.includes('id="todo-cal" data-now="c-lists"') && withCals.includes('id="event-cal" data-now=""') && withCals.includes('Todos stay on your ship')
  && withCals.indexOf('id="prefs"') < withCals.indexOf('Executor'));
ok('the graph takes mouse, pen and touch as pointers: a pinch zooms and moves it, and nothing is left on window',
  src.includes('canvas.onpointerdown = function (ev) {') && src.includes('zoomAbout(pinch.zoom * spread(t) / pinch.d, pinch.mid.x, pinch.mid.y, pinch.zoom, pinch.px, pinch.py);')
  && !src.includes('window.onmouse') && !src.includes('window.ontouch') && src.includes("bd = touchy ? 24 : 12"));
ok('a refresh that brings no new body does not settle the layout again',
  src.includes('var hot = 220, steps = added ? 0 : hot,'));
ok('the graph is drawn only while something moves, and fitted to its canvas',
  src.includes('if (settling || graphView.touching || frames > 0) graphTimer = requestAnimationFrame(loop);')
  && src.includes('return graphView.zoom * Math.min(s.w, s.h) * 0.45 / R;') && !src.includes('g.nodes.indexOf('));
ok('the diagram is flat and centred on a body: no turning, no spin, a tap centres on what it picks, and an empty pane keeps the legend',
  src.includes('if (!what) pane.innerHTML = emptyPane();') && !src.includes('graphView.ry') && !src.includes('spin') && src.includes('graphView.focus = what.id;')
  && src.includes('if (fp) { fp.x *= 0.7; fp.y *= 0.7; fp.vx = 0; fp.vy = 0; }'));
const css = require('fs').readFileSync(require('path').join(__dirname, '..', 'code', 'nex', 'orrery', 'orrery.css'), 'utf8');
ok('the page has its own dark palette, and the diagram draws in the page\'s colours, labels haloed',
  css.includes('@media (prefers-color-scheme: dark)') && css.includes(':root { color-scheme: light dark; }')
  && src.includes("return { ink: v('--ink', '#101541'), muted: v('--muted', '#6b6f80'), card: v('--card', '#ffffff') };")
  && !src.includes("ctx.fillStyle = '#101541'") && !src.includes("ctx.strokeStyle = '#101541'") && src.includes('ctx.strokeText(text, at[0], at[1]);'));
ok('a label goes where no label before it lies and inside the canvas, or is left out unless it must be drawn',
  src.includes('free = x >= 2 && x + w <= room.w - 2 && y - h >= 0 && y + 3 <= room.h;') && src.includes("if (!at) { if (!must) return; at = spots[0]; }"));
const people = render.graphOf({ me: 'person/me', bodies: [
  { id: 'person/me', kind: 'person', name: 'me', attrs: {}, involved: [] },
  { id: 'person/lin', kind: 'person', name: 'Lin', attrs: { relationship: { value: 'son' } }, involved: [] },
  { id: 'person/ann', kind: 'person', name: 'Ann', attrs: {}, involved: [] },
  { id: 'activity/sail', kind: 'activity', name: 'Sail', attrs: { participants: [{ value: { ref: 'person/me' } }, { value: { ref: 'person/lin' } }, { value: { ref: 'person/ann' } }] }, involved: [] },
  { id: 'situation/fair', kind: 'situation', name: 'Fair', attrs: { participants: [{ value: { ref: 'person/me' } }, { value: { ref: 'person/lin' } }] }, involved: [] }] }, false, false);
const inv = render.graphOf({ me: 'person/me', bodies: [
  { id: 'person/me', kind: 'person', name: 'me', attrs: {}, involved: ['situation/fair'] },
  { id: 'situation/fair', kind: 'situation', name: 'Fair', attrs: { participants: [{ value: { ref: 'person/me' } }] }, involved: [] }] }, false, false);
const said = function (a, b) { var e = people.edges.filter(function (e) { return (e.from === a && e.to === b) || (e.from === b && e.to === a); })[0]; return e && e.attr; };
ok('the relationship diagram folds activities: two bodies that share them are one line saying how many, beside what else relates them',
  !people.nodes.some(function (n) { return n.kind === 'activity'; }) && said('person/me', 'person/lin') === 'son \u00b7 1 event'
  && said('person/me', 'person/ann') === '1 event' && said('person/lin', 'person/ann') === '1 event');
ok('an open situation is a node in the relationship diagram, with a line to each participant',
  !!people.byId['situation/fair'] && people.nodes.some(function (n) { return n.id === 'situation/fair'; })
  && said('person/me', 'situation/fair') === 'participants' && said('person/lin', 'situation/fair') === 'participants' && people.edges.length === 5);
ok('a participant\'s line to a situation says participants once, not involved beside it', inv.edges.length === 1 && inv.edges[0].attr === 'participants');
const bar = render.bodies({ bodies: [], actions: [] });
ok('each kind has a box in its colour, every one on but activities',
  ['person', 'place', 'thing', 'org', 'situation', 'note'].every(function (k) { return bar.includes('data-kind="' + k + '" checked>'); })
  && bar.includes('data-kind="activity">') && !bar.includes('data-kind="activity" checked') && bar.includes('<i class="dot" style="background:#ef4444"></i>situation'));
const hidePeople = render.graphOf({ me: 'person/me', bodies: [
  { id: 'person/me', kind: 'person', name: 'me', attrs: {}, involved: [] },
  { id: 'thing/car', kind: 'thing', name: 'car', attrs: { owners: [{ value: { ref: 'person/me' } }], location: { value: { ref: 'place/shop' } } }, involved: [] },
  { id: 'place/shop', kind: 'place', name: 'shop', attrs: {}, involved: [] }] }, false, { person: true });
ok('a hidden kind that is not an event is off the diagram with its lines',
  !hidePeople.byId['person/me'] && hidePeople.edges.length === 1 && hidePeople.edges[0].attr === 'location');
const foldSits = render.graphOf({ me: 'person/me', bodies: [
  { id: 'person/me', kind: 'person', name: 'me', attrs: {}, involved: [] },
  { id: 'person/lin', kind: 'person', name: 'Lin', attrs: {}, involved: [] },
  { id: 'situation/fair', kind: 'situation', name: 'Fair', attrs: { participants: [{ value: { ref: 'person/me' } }, { value: { ref: 'person/lin' } }] }, involved: [] }] }, false, { situation: true });
ok('hidden situations fold into a count on the line between those they shared', !foldSits.nodes.some(function (n) { return n.kind === 'situation'; })
  && foldSits.edges.length === 1 && foldSits.edges[0].attr === '1 event');
ok('nothing hidden shows every kind as a node', render.graphOf({ bodies: [{ id: 'activity/a', kind: 'activity', name: 'a', attrs: { participants: [{ value: { ref: 'person/me' } }] }, involved: [] }, { id: 'person/me', kind: 'person', name: 'me', attrs: {}, involved: [] }] }, false, {}).nodes.length === 2);
ok('a refresh holds while a form is dirty or focused, and only the owner\'s own moves force one',
  src.includes("if (editing() && !force) { say('not refreshed: a form holds unsaved changes'); return; }")
  && src.includes('if (dirty || graphView.touching) return true;')
  && src.includes('function later(gone) { dirty = typedNote(); awaitGone = Array.isArray(gone) ? gone : null; awaitMove = awaitGone ? 20 : 10; setTimeout(function () { refresh(!dirty); }, 300); }')
  && src.includes("window.addEventListener('hashchange', function () { dirty = false; refresh(true); });"));
ok('a refine holds the row\'s move buttons while it runs and frees them on a refusal or an error',
  src.indexOf("holdMoves(true);") > src.indexOf("b.dataset.refine) {") && src.indexOf("holdMoves(true);") < src.indexOf("post('/actions/' + seg(rid) + '/refine'")
  && src.includes("view.querySelectorAll('[data-move^=\"' + rid + ':\"]')")
  && src.indexOf("holdMoves(false);", src.indexOf("} else if (el) el.textContent = (d && d.note) || 'not refined';")) > 0
  && src.slice(src.indexOf(".catch(function (e) { var el = noteOf();")).split('\n')[0].includes('holdMoves(false);'));
ok('a refresh whose fetches were out while the owner typed on the same view does not draw over it',
  src.includes("if (el && (el.tagName === 'TEXTAREA' || el.tagName === 'INPUT')) { dirty = true; edits += 1; }")
  && src.includes("if ((edits !== mark || graphView.touching) && v.here === drawn) { held = true; say('not refreshed: a form holds unsaved changes'); return false; }")
  && (src.match(/view\.innerHTML = /g) || []).length === 2
  && src.includes("drawView(v, seen[v.here], function (html) { view.innerHTML = html; drawn = v.here; return true; });")
  && src.includes("show(settings(") && src.includes("if (!held) { say(pending); pending = ''; }"));
ok('a refine keeps the page-wide dirty flag on submit and fetches the revised row on success',
  src.indexOf("dirty = Array.prototype.some.call(view.querySelectorAll('[data-refine-text]')") > src.indexOf("post('/actions/' + seg(rid) + '/refine'")
  && src.indexOf("refresh(true);", src.indexOf("post('/actions/' + seg(rid) + '/refine'")) < src.indexOf("} else if (el) el.textContent = (d && d.note) || 'not refined';")
  && !src.slice(src.indexOf("b.dataset.refine) {"), src.indexOf("post('/actions/' + seg(rid) + '/refine'")).includes('dirty = false'));
// following Armillary (version 96): the card lists each setting, offers
// a way back for one picked by hand, and is absent without Armillary
const armWeek = (a) => render.settings({ kinds: {} }, {}, {}, {}, {}, {}, {}, {}, {}, {}, [], [], {}, {}, {}, {}, {}, {}, [], [], [], {}, {}, { armillary: a });
const armOn = armWeek({ offered: true, rev: 3, mode: 'lease', settings: {
  generator: { following: true, applied: true, model: 'g/1' }, mail: { following: false, applied: true, model: 'mine/1' } } });
ok('the Armillary card names the vendor\'s model and offers the way back for a hand pick',
  armOn.includes('<h2>Armillary</h2>') && armOn.includes('<code>g/1</code>')
  && armOn.includes('data-follow-armillary="mail"') && armOn.includes('data-follow-armillary=""'));
ok('a ship whose Armillary offers nothing shows no Armillary card',
  !armWeek({ offered: false }).includes('<h2>Armillary</h2>') && !armWeek(undefined).includes('<h2>Armillary</h2>'));
// the browsing reader (version 98)
const brNone = render.browsingCard({ enabled: true, model: '', exclude: ['news.example'], interval_hours: 3 }, {});
const brSet = render.browsingCard({ enabled: true, model: 'zdr/one', exclude: [], interval_hours: 3 },
  { pass_at: '2026-10-09T12:00:00Z', unread: 12, tied: 3, sent: 3, filed: 2, trimmed: 4, notes: ['gate: worth reading'] });
ok('with no model the browsing card says pages wait, and lists the sites the owner left out',
  brNone.includes('No ZDR model yet') && brNone.includes('news.example') && brNone.includes('data-save-browsing="1"') && brNone.includes('data-browsing-wake="1"'));
ok('with a model the card says what the last pass did',
  !brSet.includes('No ZDR model yet') && brSet.includes('12 new pages, 3 tied to something, 3 read by the model, 2 filed, 4 old texts trimmed') && brSet.includes('gate: worth reading'));
ok('the settings view carries the browsing card', render.settings({}, {}, {}, {}, {}, {}, {}, {}, {}, {}, [], [], {}, {}, {}, {}, {}, {}, [], [], [], {}, {},
  { browsing: { enabled: true, model: '' }, browsingLast: {} }).includes('<h2>Browsing</h2>'));
console.log('ALL OK (' + n + ' checks)');
