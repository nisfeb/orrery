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
ok('the generator card shows the settings with the key masked', genSettings.includes('<h2>Generator</h2>') && genSettings.includes('name="model" value="moonshotai/kimi-k3"') && genSettings.includes('a key is set') && !genSettings.includes('sk-'));
ok('the generator card offers a run and a save', genSettings.includes('data-generate="1"') && genSettings.includes('data-save-generator="1"'));
ok('the last pass is summarised', genSettings.includes('3 filed, 1 dropped') && genSettings.includes('$0.0229') && genSettings.includes('the trip is stale') && genSettings.includes('Model calls today: 4 (1 urgent)') && genSettings.includes('This month: $1.23'));
ok('the limits are on the card', genSettings.includes('name="cooldown_minutes" value="60"') && genSettings.includes('name="max_daily" value="24"') && genSettings.includes('name="max_urgent" value="5"'));
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
const chatLast = { since: '2026-09-21T22:00:00Z', at: '2026-09-22T22:07:08Z', read: 2, filed: 3, strangers: 1, held: 0, read_today: 2, day: '2026-09-22', notes: ['groups desk not installed'], down: null };
const chatSettings = render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, {}, chat, chatLast, { items: [{ id: '~sampel-palnet', name: 'Sam' }, { id: '~zod', name: '' }], note: '' }, { items: [], note: 'groups desk not installed' });
ok('the chat card follows telegram with the picked DM listed by its nickname and a picker for more', chatSettings.indexOf('<h2>Telegram</h2>') < chatSettings.indexOf('<h2>Chat</h2>') && chatSettings.includes('<ul class="picked" data-picked="dms"><li data-id="~sampel-palnet">Sam <small class="muted">~sampel-palnet</small>') && chatSettings.includes('name="dms-find"') && chatSettings.includes('data-picked="channels"><li class="muted" data-empty="1">none picked</li>') && chatSettings.includes('groups desk not installed'));
ok('the chat card carries the people map, the switches and the buttons', chatSettings.includes('person/sam') && chatSettings.includes('name="read_own"') && chatSettings.includes('data-save-chat="1"') && chatSettings.includes('data-chat-wake="1"'));
ok('the chat card shows the last pass and its note, and the channel note when there are none', chatSettings.includes('read 2, filed 3, strangers 1') && chatSettings.includes('groups desk not installed') && chatSettings.includes('Read today: 2'));
ok('a stamp on the page is local time, the test running in UTC', chatSettings.includes('Last pass at 2026-09-22 22:07:08'));
ok('a chat reader that never ran shows the card without a last line', !render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, {}, {}, {}, {}, {}).includes('strangers '));
const chatDown = render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, tgLast, {}, chat, { at: '2026-09-22T22:07:08Z', since: '2026-09-22T21:00:00Z', down: { at: '2026-09-22T22:07:08Z', notes: ['model: 502'] } }, {}, {});
ok('a model down on the chat card is said in red with its note', chatDown.includes('The model could not be read') && chatDown.includes('model: 502'));
ok('the telegram card follows reconcile with the token masked and the secret wanted', tgSettings.indexOf('<h2>Reconcile</h2>') < tgSettings.indexOf('<h2>Telegram</h2>') && tgSettings.includes('a token is set') && tgSettings.includes('no secret set') && !tgSettings.includes('123:abc'));
ok('the card holds chats, people, thresholds and the cap', tgSettings.includes('name="chats" value="1001"') && tgSettings.includes('&quot;1001&quot;: &quot;person/me&quot;') && tgSettings.includes('name="gate" value="30"') && tgSettings.includes('name="max_daily_messages" value="500"'));
ok('the card asks Telegram what it holds', tgSettings.includes('data-webhook-info="1"') && tgSettings.includes('id="webhook-info"'));
ok('the card offers save and register', tgSettings.includes('data-save-telegram="1"') && tgSettings.includes('data-webhook="1"'));
ok('the card offers to make a secret', tgSettings.includes('data-make-secret="1"'));
ok('the last update is summarised', tgSettings.includes('Last update 7') && tgSettings.includes('facts') && tgSettings.includes('Read today: 3') && tgSettings.includes('gate: 90, read'));
ok('a kept update is shown with its notes and a wake button', render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, { update_id: 5, at: '2026-09-21T01:00:00Z', outcome: 'facts', down: { update_id: 9, at: '2026-09-21T02:00:00Z', notes: ['model: 404 no endpoints'] } }).includes('Update 9 is waiting since') && render.settings({ kinds: {} }, {}, gen, genLast, {}, tg, { down: { update_id: 9, at: '2026-09-21T02:00:00Z', notes: ['model: 404 no endpoints'] } }).includes('data-wake="1"'));
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
const src = require('fs').readFileSync(require('path').join(__dirname, '..', 'code', 'nex', 'orrery', 'orrery.js'), 'utf8');
ok('a refresh holds while a form is dirty or focused, and only the owner\'s own moves force one',
  src.includes("if (editing() && !force) { say('not refreshed: a form holds unsaved changes'); return; }")
  && src.includes("view.addEventListener('input'") && src.includes('if (dirty) return true;')
  && src.includes('dirty = false; setTimeout(function () { refresh(true); }, 300);')
  && src.includes("window.addEventListener('hashchange', function () { dirty = false; refresh(true); });")
  && !src.includes("setInterval(function () { if (!document.hidden) refresh(true); }"));
ok('a refine holds the row\'s move buttons while it runs and frees them on a refusal or an error',
  src.indexOf("holdMoves(true);") > src.indexOf("b.dataset.refine) {") && src.indexOf("holdMoves(true);") < src.indexOf("post('/actions/' + seg(rid) + '/refine'")
  && src.includes("view.querySelectorAll('[data-move^=\"' + rid + ':\"]')")
  && src.indexOf("holdMoves(false);", src.indexOf("} else if (el) el.textContent = (d && d.note) || 'not refined';")) > 0
  && src.slice(src.indexOf(".catch(function (e) { var el = noteOf();")).split('\n')[0].includes('holdMoves(false);'));
ok('a refine leaves the box before the click, keeps the page-wide dirty flag on submit, and fetches the revised row on success',
  src.includes("if (btn) { e.preventDefault(); el.blur(); btn.focus(); btn.click(); }")
  && src.includes("if (inp) { inp.value = ''; inp.blur(); }")
  && src.indexOf("dirty = Array.prototype.some.call(view.querySelectorAll('[data-refine-text]')") > src.indexOf("post('/actions/' + seg(rid) + '/refine'")
  && src.indexOf("refresh(true);", src.indexOf("post('/actions/' + seg(rid) + '/refine'")) < src.indexOf("} else if (el) el.textContent = (d && d.note) || 'not refined';")
  && !src.slice(src.indexOf("b.dataset.refine) {"), src.indexOf("post('/actions/' + seg(rid) + '/refine'")).includes('dirty = false'));
console.log('ALL OK (' + n + ' checks)');
