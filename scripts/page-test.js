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
  ],
  situations: ['situation/2026-09-16-breakdown'],
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
];

let n = 0;
function ok(label, cond) { n += 1; assert.ok(cond, label); console.log('  ok   ' + label); }

const bodies = render.bodies(state);
ok('bodies are grouped by kind', bodies.indexOf('<h2>person</h2>') < bodies.indexOf('<h2>situation</h2>') && bodies.includes('<h2>thing</h2>'));
ok('every body links to its view', bodies.includes('href="#body/person/me"') && bodies.includes('href="#body/thing/subaru"'));
ok('names are escaped', !bodies.includes('<b>Subaru</b>') && bodies.includes('&lt;b&gt;Subaru&lt;/b&gt;'));
ok('open situations are listed', bodies.includes('situation/2026-09-16-breakdown'));

const body = render.body(view);
ok('the body view names the body', body.includes('the Subaru') && body.includes('thing/subaru'));
ok('a ref value is a link to that body', body.includes('href="#body/place/johns-machine-shop"'));
ok('the timeline shows every row with its status', body.includes('superseded') && body.includes('retracted') && body.includes('Route 9'));
ok('only a live row gets a retract button', (body.match(/data-retract="/g) || []).length === 1 && body.includes('data-retract="3-c"'));
ok('a source pointer is shown', body.includes('talon-dm') && body.includes('m3'));
ok('the retraction note is shown', body.includes('wrong car'));
ok('involved and actions are listed', body.includes('situation/2026-09-16-breakdown') && body.includes('Call the shop'));

const inboxHtml = render.inbox(inbox);
ok('a proposed action offers approve and dismiss', inboxHtml.includes('data-move="p1:approved"') && inboxHtml.includes('data-move="p1:dismissed"') && !inboxHtml.includes('data-move="p1:done"'));
ok('an approved action offers done, failed and dismiss', inboxHtml.includes('data-move="a1:done"') && inboxHtml.includes('data-move="a1:failed"') && inboxHtml.includes('data-move="a1:dismissed"') && !inboxHtml.includes('data-move="a1:approved"'));
ok('about ids link to bodies', inboxHtml.includes('href="#body/person/sarah"'));
ok('an empty inbox says so', render.inbox([]).includes('Nothing waiting'));

const settings = render.settings({ kinds: { person: { attrs: ['status'] } } }, { auto: ['task'], push: 'proposed', retention_days: 365, sensitive: ['health'] });
ok('the schema is editable JSON', settings.includes('id="schema"') && settings.includes('&quot;person&quot;'));
ok('the policy is editable JSON', settings.includes('id="policy"') && settings.includes('&quot;health&quot;'));

ok('esc handles the five characters', render.esc('<&>"\'') === '&lt;&amp;&gt;&quot;&#39;');
ok('fmtValue renders strings, refs and objects', render.fmtValue('x') === 'x' && render.fmtValue({ ref: 'a/b' }).includes('#body/a/b') && render.fmtValue({ n: 1 }) === '{&quot;n&quot;:1}');
console.log('ALL OK (' + n + ' checks)');
