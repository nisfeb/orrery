#!/usr/bin/env python3
"""armillary-key-matrix.py HOST JAR
The generator's Armillary address and key, read from the offer at each
call, against a fake ship that has Armillary installed and orrery's road
to its app-inference.json approved. A stub model on this machine records
each call's Authorization header; the gate lays test offers into
Armillary's app-inference.json and calls POST /api/instruct. A call runs
on the offer's key, a key rotated in the offer is the very next call's,
generator.json never holds the vendor's address or key, and a key the
owner types wins and is kept. The offer's address ends in /v1 as an
Armillary proxy's does, and the decider asks <address without
/v1>/alpha/decisions (Armillary 34) on the same key, for the vendor's
decision model; the read channel is switched on for that. The three
files are put back as they were, so it is safe to rerun. Fake ships only: it rewrites Armillary's offer.

Version 106: a model picked by hand keeps the vendor's key; an address
and key typed are the owner's, and following again takes the vendor's
back; a key typed alone goes to the default address (checked stored,
never called, since that is the real openrouter.ai); the writer's rise
sorts an own pick from before into a copy (gone) or the owner's key
(kept), each after a reload; and place lookups hold no proxy address
or key. Their files, search.json and Armillary's, are put back too."""
import http.server, json, re, sys, threading, time, urllib.parse
from gate import fails, check, wait, dictish
import gate

HOST, JAR = sys.argv[1].rstrip('/'), sys.argv[2]
if not re.match(r'https?://(localhost|127\.0\.0\.1)(:\d+)?$', HOST):
    sys.exit('armillary-key-matrix: fake ships only; it rewrites Armillary\'s offer')
ARM = '/apps/shell.shell/desks/armillary.desk/desk/data/armillary.armillary_app/app-inference.json'
GEN = '/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/generator.json'
READ = '/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/read.json'
SEARCH = '/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/search.json'
APP = '/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app'
seen = []


class Stub(http.server.BaseHTTPRequestHandler):
    """a model that answers instruct with nothing to do and the decider
    with nothing worth reading, and keeps each call's path, Authorization
    header and model"""
    def do_POST(self):
        asked = json.loads(self.rfile.read(int(self.headers.get('content-length') or 0)) or b'{}')
        seen.append((self.path, self.headers.get('authorization'), asked.get('model')))
        if self.path.endswith('/decisions'):
            out = {'answers': {'worth_reading': {'type': 'noul', 'noul': 0}}}
        else:
            out = {'choices': [{'message': {'content': json.dumps({'reply': 'noted', 'actions': []})}}],
                   'usage': {'prompt_tokens': 1, 'completion_tokens': 1, 'cost': 0}}
        body = json.dumps(out).encode()
        self.send_response(200)
        self.send_header('content-type', 'application/json')
        self.send_header('content-length', str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def log_message(self, *a): pass


srv = http.server.HTTPServer(('127.0.0.1', 0), Stub)
STUB = 'http://127.0.0.1:%d' % srv.server_address[1]
threading.Thread(target=srv.serve_forever, daemon=True).start()


def api(method, path, body=None):
    return gate.curl(method, HOST + '/apps/orrery/api' + path, body, jar=JAR, timeout=150)


def read(path):
    code, d = gate.curl('GET', HOST + '/grubbery/api/file' + path, jar=JAR)
    return d if code == 200 and isinstance(d, dict) else None


def lay(path, doc):
    """a file written through the explorer, past the app's writer"""
    form = urllib.parse.urlencode({'action': 'write-text', 'content': json.dumps(doc)})
    code, _ = gate.curl('POST', HOST + '/grubbery/ball' + path, jar=JAR, raw=form,
                        headers=['content-type: application/x-www-form-urlencoded'])
    return code == 200


def offer(key):
    return {'mode': 'lease', 'base_url': STUB + '/v1', 'key': key, 'search': {},
            'suggested': {'rev': 1, 'models': {'default': 'stub/model', 'orrery_decider': 'typesafe/jev-1.13'}}}


def instruct():
    """one instruct call, and the key its model call carried"""
    code, _ = api('POST', '/instruct', {'text': 'the key matrix is running'})
    chat = [a for p, a, _ in seen if p.endswith('/chat/completions')]
    return code, chat[-1] if chat else None


code, arm = api('GET', '/armillary')
if not dictish(arm).get('offered'):
    sys.exit('armillary-key-matrix: orrery reads no Armillary here; install it '
             '(armillary\'s scripts/dev-deploy.py --add) and approve orrery\'s road')
was_arm, was_gen, was_read, was_search = read(ARM), read(GEN), read(READ), read(SEARCH)
try:
    # ---- a call runs on the offer's key, and the file holds none ----
    #  a day's cap of its own, so earlier runs today do not spend this one's calls
    check('a fresh following generator.json is laid', lay(GEN, {'enabled': False, 'max_daily': 1000}))
    check('the first offer is laid', lay(ARM, offer('key-one')))
    got = instruct()
    check('a call runs on the offer\'s key', got == (200, 'Bearer key-one'), got)
    f = dictish(read(GEN))
    check('generator.json holds no key or address', 'api_key' not in f and 'url' not in f, f)
    code, g = api('GET', '/generator')
    g = dictish(g)
    check('GET /api/generator: a key is set, the offer\'s address, the key never shown',
          g.get('api_key_set') is True and g.get('url') == STUB + '/v1' and 'api_key' not in g, g)
    # ---- a rotated key is the next call's, inside the minute the follow fiber waits ----
    lay(ARM, offer('key-two'))
    t = time.time()
    got = instruct()
    check('the rotated key is the next call\'s (%.1f s after the rotation)' % (time.time() - t),
          got == (200, 'Bearer key-two'), got)
    # ---- the follow fiber lays the model and the revision, and still no key ----
    f = dictish(wait('the follow fiber lays the offer within a minute and a half',
                     lambda: (lambda d: d if 'armillary_rev' in d else None)(dictish(read(GEN))), 90))
    check('it laid the model and no key or address',
          f.get('model') == 'stub/model' and 'api_key' not in f and 'url' not in f, f)
    got = instruct()
    check('a call still runs on the current key', got == (200, 'Bearer key-two'), got)
    # ---- the decider asks the decisions route beside the offer's /v1, on its key ----
    api('PUT', '/read/settings', {'enabled': True})
    code, said = api('POST', '/read', {'text': 'The key matrix is reading this.', 'title': 'key matrix'})
    check('a text is handed to the read channel', code == 200 and bool(dictish(said).get('id')), (code, said))
    hit = wait('the reader asks the decider within a minute',
               lambda: next((c for c in seen if c[0].endswith('/decisions')), None), 60)
    check('at <address without /v1>/alpha/decisions, on the current key, for the vendor\'s decision model',
          hit == ('/alpha/decisions', 'Bearer key-two', 'typesafe/jev-1.13'), hit)
    # ---- a model picked by hand is the owner's model on the vendor's key (version 106) ----
    api('PUT', '/generator', {'url': STUB + '/v1', 'model': 'owner/model'})
    time.sleep(1)
    f = dictish(read(GEN))
    a = dictish(dictish(dictish(api('GET', '/armillary')[1]).get('settings')).get('generator'))
    check('a model picked by hand stops only the model following, and stores no key',
          f.get('follow_armillary') is False and 'own_key' not in f and 'api_key' not in f and 'url' not in f
          and a.get('following') is False and a.get('own_key') is False, (f, a))
    got = instruct()
    check('and the call runs on the vendor\'s key still', got == (200, 'Bearer key-two'), got)
    # ---- an address and key the owner types are theirs: kept, and they win ----
    api('PUT', '/generator', {'url': STUB + '/own/v1', 'model': 'owner/model', 'api_key': 'owner-key'})
    time.sleep(1)
    f = dictish(read(GEN))
    check('a typed address and key are the owner\'s, kept in the file',
          f.get('own_key') is True and f.get('api_key') == 'owner-key' and f.get('url') == STUB + '/own/v1', f)
    got = instruct()
    check('the owner\'s key wins over the offer', got == (200, 'Bearer owner-key'), got)
    # ---- following again takes the vendor's back ----
    api('POST', '/armillary/follow', {'feature': 'generator'})
    time.sleep(1)
    f = dictish(read(GEN))
    check('following again takes the vendor\'s model, address and key back',
          'own_key' not in f and 'api_key' not in f and 'url' not in f and f.get('follow_armillary') is not False, f)
    got = instruct()
    check('and the call runs on the vendor\'s key', got == (200, 'Bearer key-two'), got)
    # ---- a key typed alone goes to the default address, never the vendor's: stored, not called ----
    api('PUT', '/generator', {'url': STUB + '/v1', 'api_key': 'owner-key-2'})
    time.sleep(1)
    f = dictish(read(GEN))
    check('a key typed alone goes to the default address, never the vendor\'s',
          f.get('own_key') is True and f.get('url') == 'https://openrouter.ai/api/v1' and f.get('api_key') == 'owner-key-2', f)
    # ---- an own pick from before 106, sorted out by the writer's rise ----
    def reloaded():
        gate.curl('POST', HOST + '/apps/grubbery/permits/reload', {'app': APP}, jar=JAR, timeout=120)
        time.sleep(3)
        return wait('orrery answers after the reload', lambda: api('GET', '/version')[0] == 200, 120)
    lay(GEN, {'follow_armillary': False, 'armillary_rev': 1, 'model': 'owner/model', 'url': STUB + '/v1', 'api_key': 'key-two', 'max_daily': 1000})
    reloaded()
    f = dictish(read(GEN))
    check('a copy of the vendor\'s key taken with a model pick goes; the model stays the owner\'s',
          'api_key' not in f and 'url' not in f and 'own_key' not in f and f.get('follow_armillary') is False and f.get('model') == 'owner/model', f)
    lay(GEN, {'follow_armillary': False, 'armillary_rev': 1, 'model': 'owner/model', 'url': STUB + '/own/v1', 'api_key': 'owner-key', 'max_daily': 1000})
    reloaded()
    f = dictish(read(GEN))
    check('an own key from before is kept, marked the owner\'s', f.get('own_key') is True and f.get('api_key') == 'owner-key', f)
    # ---- place lookups run on the vendor's proxy address and key, stored nowhere ----
    lay(SEARCH, {})
    lay(ARM, dict(offer('key-two'), search={'url': STUB + '/brave', 'key': 'id.secret'}))
    f = dictish(wait('the follow fiber lays the search offer within a minute and a half',
                     lambda: (lambda d: d if 'armillary_rev' in d else None)(dictish(read(SEARCH))), 90))
    sv = dictish(api('GET', '/search')[1])
    check('search.json holds no address or key; place lookups run on the vendor\'s',
          'api_key' not in f and 'api_url' not in f and f.get('enabled') is True and sv.get('api_key_set') is True and sv.get('api_url') == STUB + '/brave', (f, sv))
finally:
    lay(ARM, was_arm if was_arm is not None else {})
    lay(GEN, was_gen if was_gen is not None else {})
    lay(READ, was_read if was_read is not None else {})
    lay(SEARCH, was_search if was_search is not None else {})
    srv.shutdown()

print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK (%d checks)' % gate.count[0])
sys.exit(1 if fails else 0)
