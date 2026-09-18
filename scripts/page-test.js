#!/usr/bin/env node
// The page's render functions against fixtures: what the owner sees for
// a state view, a body view, the inbox and the settings. Run: node
// scripts/page-test.js. Exits 1 on the first failed assertion.
'use strict';
const assert = require('assert');
const path = require('path');
const render = require(path.join(__dirname, '..', 'code', 'nex', 'orrery', 'orrery.js'));

const state = {
  rev: 1789600000000, at: '2026-09-17T00:00:00Z', me: 'person/me',
  bodies: [
    { id: 'person/me', kind: 'person', name: 'me', aliases: [], ship: '~wex', attrs: { status: { value: 'home', at: '2026-09-16T22:00:00Z', by: 'talon', source: { kind: 'talon-dm', id: 'm1' }, obs: '1-a' } }, involved: ['situation/2026-09-16-breakdown'] },
    { id: 'thing/subaru', kind: 'thing', name: 'the <b>Subaru</b>', aliases: ['the car'], ship: null, attrs: {}, involved: [] },
    { id: 'situation/2026-09-16-breakdown', kind: 'situation', name: 'breakdown', aliases: [], ship: null, attrs: {}, involved: [] },
    { id: 'situation/2026-09-20-dinner', kind: 'situation', name: 'Dinner at eight', aliases: [], ship: null, attrs: { started: { value: '2026-09-20T23:00:00Z', at: '2026-09-17T00:00:00Z', by: 'talon', source: { kind: 'talon-dm', id: 'm9' }, obs: '3-c' } }, involved: [] },
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
function ok(label, cond) { n += 1; assert.ok(cond, label); console.log('  ok   ' + label); }

const bodies = render.bodies(state);
ok('bodies are grouped by kind', bodies.indexOf('<h2>person</h2>') >= 0 && bodies.indexOf('<h2>person</h2>') < bodies.indexOf('<h2>situation</h2>') && bodies.includes('<h2>thing</h2>'));
ok('every body links to its view', bodies.includes('href="#body/person/me"') && bodies.includes('href="#body/thing/subaru"'));
ok('names are escaped', !bodies.includes('<b>Subaru</b>') && bodies.includes('&lt;b&gt;Subaru&lt;/b&gt;'));
ok('open situations are listed', bodies.includes('situation/2026-09-16-breakdown'));
ok('open situations show their names with the id as subtext', bodies.includes('>Dinner at eight') && bodies.indexOf('<h2>Open situations</h2>') < bodies.indexOf('Dinner at eight') && bodies.indexOf('Dinner at eight') < bodies.indexOf('<span class="id">situation/2026-09-20-dinner</span>'));
ok('open situations come soonest first, undated last', bodies.indexOf('>Dinner at eight') < bodies.indexOf('>breakdown') && bodies.indexOf('>breakdown') < bodies.indexOf('<h2>person</h2>'));
ok('a situation phase comes from its times, not a stored guess', render.phase({ attrs: { status: { value: 'under way' }, starts: { value: '2026-12-05T19:00:00Z' }, ends: { value: '2026-12-05T20:00:00Z' } } }, '2026-09-18T12:00:00Z') === 'upcoming'
  && render.phase({ attrs: { starts: { value: '2026-09-18T11:00:00Z' }, ends: { value: '2026-09-18T13:00:00Z' } } }, '2026-09-18T12:00:00Z') === 'under way'
  && render.phase({ attrs: { starts: { value: '2026-09-18T11:00:00Z' }, ends: { value: '2026-09-18T11:30:00Z' } } }, '2026-09-18T12:00:00Z') === 'over'
  && render.phase({ attrs: { status: { value: 'closed' }, ends: { value: '2099-01-01T00:00:00Z' } } }, '2026-09-18T12:00:00Z') === 'closed'
  && render.phase({ attrs: {} }, '2026-09-18T12:00:00Z') === 'open');
ok('the open situations list shows the phase', bodies.includes('>Dinner at eight <span class="muted">upcoming, '));
ok('a closed situation folds under past', bodies.includes('<summary>past situations (1)</summary>') && bodies.indexOf('situation/2026-09-01-preop') > bodies.indexOf('<details class="past">'));
ok('an open situation is not under past', bodies.indexOf('situation/2026-09-16-breakdown') < bodies.indexOf('<details class="past">'));

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
  bodyWithState.includes('<h2>Involved in</h2><div class="bodies"><a href="#body/situation/2026-09-20-dinner">Dinner at eight <span class="muted">upcoming, 2026-09-20 23:00:00</span><span class="id">situation/2026-09-20-dinner</span></a>')
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

const settings = render.settings({ kinds: { person: { attrs: ['status'] } } }, { auto: ['task'], push: 'proposed', retention_days: 365, sensitive: ['health'] });
ok('the schema is editable JSON', settings.includes('id="schema"') && settings.includes('&quot;person&quot;'));
ok('the policy is editable JSON', settings.includes('id="policy"') && settings.includes('&quot;health&quot;'));

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
console.log('ALL OK (' + n + ' checks)');
