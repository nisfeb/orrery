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
files are put back as they were, so it is safe to rerun. Fake ships only: it rewrites Armillary's offer."""
import http.server, json, re, sys, threading, time, urllib.parse
from gate import fails, check, wait, dictish
import gate

HOST, JAR = sys.argv[1].rstrip('/'), sys.argv[2]
if not re.match(r'https?://(localhost|127\.0\.0\.1)(:\d+)?$', HOST):
    sys.exit('armillary-key-matrix: fake ships only; it rewrites Armillary\'s offer')
ARM = '/apps/shell.shell/desks/armillary.desk/desk/data/armillary.armillary_app/app-inference.json'
GEN = '/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/generator.json'
READ = '/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/read.json'
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
    chat = [a for p, a, _ in seen if p == '/v1/chat/completions']
    return code, chat[-1] if chat else None


code, arm = api('GET', '/armillary')
if not dictish(arm).get('offered'):
    sys.exit('armillary-key-matrix: orrery reads no Armillary here; install it '
             '(armillary\'s scripts/dev-deploy.py --add) and approve orrery\'s road')
was_arm, was_gen, was_read = read(ARM), read(GEN), read(READ)
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
    # ---- a key the owner types is theirs: kept, and it wins over the offer ----
    api('PUT', '/generator', {'url': STUB + '/v1', 'model': 'stub/model', 'api_key': 'owner-key'})
    time.sleep(1)
    f = dictish(read(GEN))
    check('a typed key is the owner\'s pick, kept in the file',
          f.get('follow_armillary') is False and f.get('api_key') == 'owner-key', f)
    got = instruct()
    check('the owner\'s key wins over the offer', got == (200, 'Bearer owner-key'), got)
finally:
    lay(ARM, was_arm if was_arm is not None else {})
    lay(GEN, was_gen if was_gen is not None else {})
    lay(READ, was_read if was_read is not None else {})
    srv.shutdown()

print()
print('FAILED: ' + ', '.join(fails) if fails else 'ALL OK (%d checks)' % gate.count[0])
sys.exit(1 if fails else 0)
