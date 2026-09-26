"""upgrade-seed.py <ship> <jar>: old and odd data, fed to the previous
release through its own routes before the new code is written over it,
so the new code meets at start whatever the old accepted: settings of
odd types, read-inbox items of odd fields, observations at the edges of
what the writer takes, and actions of odd shapes. See the README,
Development."""
import sys, json, time
import os; sys.path.insert(0, os.path.dirname(os.path.abspath(__file__))); import gate
H, JAR = sys.argv[1:3]; API = H + '/apps/orrery/api'
def say(label, r): print('%-44s %s %s' % (label, r[0], str(r[1])[:90]))
c = lambda *a, **k: gate.curl(*a, jar=JAR, **k)
now = int(time.time())
# settings with odd types and values: whatever v59 stores, the new readers read at start
say('chat odd settings', c('PUT', API + '/chat', {'poll_minutes': 'ten', 'dms': 5, 'channels': {'x': 1}, 'people': ['a'], 'gate': -3, 'backfill_hours': 10**9, 'enabled': 'yes'}))
say('mail odd settings', c('PUT', API + '/mail', {'poll_minutes': 0, 'backfill_hours': 99999, 'enabled': 'yes', 'model': 7}))
say('read odd settings', c('PUT', API + '/read/settings', {'max_daily_messages': 'lots', 'gate': 500, 'enabled': True}))
say('generator odd settings', c('PUT', API + '/generator', {'max_daily': -1, 'cooldown_minutes': 'x', 'timezone': 12, 'api_key': None}))
say('telegram odd settings', c('PUT', API + '/telegram', {'chats': 'all', 'people': {'1': 5}, 'enabled': False}))
# read-inbox items in v59's shape (no scope), with odd fields; no model key, so they wait
say('read item odd fields', c('POST', API + '/read', {'text': 'upgrade probe', 'who': 5, 'at': 'garbage', 'source': 'str', 'title': ['a']}))
say('read item big', c('POST', API + '/read', {'text': 'x' * 60000, 'title': 'big'}))
say('read item unicode', c('POST', API + '/read', {'text': 'café ☃ \U0001f600', 'source': {'kind': 'web', 'id': 'https://example.test/upgrade'}}))
# observations at the edges of what v59 accepts
obs = [
  {'subject': 'thing/upgrade-probe', 'attr': 'status', 'value': {'deep': {'er': [1, 2, {'x': None}]}}, 'at': '2026-09-20T00:00:00Z', 'source': {'kind': 'user', 'id': 'upgrade'}},
  {'subject': 'thing/upgrade-probe', 'attr': 'location', 'value': {'ref': 'place/nowhere-at-all'}, 'at': '2026-09-20T00:00:00Z', 'source': {'kind': 'user', 'id': 'upgrade'}},
  {'subject': 'thing/upgrade-probe', 'attr': 'starts', 'value': '2999-01-01T00:00:00Z', 'at': '2026-09-20T00:00:00Z', 'until': '2026-09-19T00:00:00Z', 'conf': 0, 'source': {'kind': 'user', 'id': 'upgrade'}},
  {'subject': 'thing/upgrade-probe', 'attr': 'a' * 48, 'value': 'y' * 1990, 'at': '2026-09-20T00:00:00Z', 'source': {'kind': 'user', 'id': 'upgrade'}},
  {'subject': 'thing/upgrade-probe', 'attr': 'ends', 'value': 'not a time', 'at': '2026-09-20T00:00:00Z', 'source': {'kind': 'user', 'id': 'upgrade'}},
  {'subject': 'thing/upgrade-probe', 'attr': 'count', 'value': 1e300, 'at': '2026-09-20T00:00:00Z', 'source': {'kind': 'user', 'id': 'upgrade'}},
]
say('observe edge values', c('POST', API + '/observe', {'bodies': [{'id': 'thing/upgrade-probe', 'name': 'Upgrade probe ☃', 'aliases': ['up']}], 'observations': obs}))
# actions of odd shapes
for label, a in [
  ('act message to nobody', {'kind': 'message', 'title': 'Upgrade probe message', 'payload': {'via': 'telegram', 'to': 'person/nobody-here', 'text': 'x'}}),
  ('act calendar bad starts', {'kind': 'calendar', 'title': 'Upgrade probe event', 'payload': {'title': 'x', 'starts': 'tomorrowish'}}),
  ('act task far due', {'kind': 'task', 'title': 'Upgrade probe task', 'due': '2999-12-31T00:00:00Z', 'payload': {'notes': {'nested': [1]}}}),
  ('act note odd payload', {'kind': 'note', 'title': 'Upgrade probe note', 'payload': {'text': 5, 'why': ['a']}}),
]:
    say(label, c('POST', API + '/act', a))
# the schema's owner keys (version 60), in shapes v59 never checked: a
# style that is not a string, preferences with odd items and a huge one
code, sch = c('GET', API + '/schema')
if code == 200 and isinstance(sch, dict):
    sch = dict(sch, style={'not': 'a string'}, preferences=['plain', 5, {'a': 1}, None, 'p' * 20000])
    say('schema odd style and preferences', c('PUT', API + '/schema', sch))
# a dismissal with the longest reason v59 takes (500 bytes), for the
# decisions the prompts now keep
code, a = c('POST', API + '/act', {'kind': 'task', 'title': 'Upgrade probe dismissed'})
if code == 200 and isinstance(a, dict):
    say('dismiss with a long reason', c('POST', API + '/actions/' + a['id'], {'status': 'dismissed', 'note': 'why ' * 120}))
# a calendar row putting the owner in an event, as v59 wrote them all
say('calendar owner row', c('POST', API + '/observe', {'bodies': [{'id': 'situation/upgrade-probe-event', 'name': 'Upgrade probe event'}], 'observations': [{'subject': 'situation/upgrade-probe-event', 'attr': 'participants', 'value': {'ref': 'person/me'}, 'source': {'kind': 'calendar', 'id': 'home/upgrade-probe'}}]}))
