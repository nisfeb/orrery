#!/usr/bin/env python3
"""Put code/ on a DEV ship as the orrery desk, the way a user adds one.

  dev-deploy.py <base-url> <cookie-jar> <code-dir> [--add] [--replace-desk]
                [--approve] [--desk NAME]

Mirrors code/ (the files that differ) into the ship's namespace at
/<desk>-dev/code through the kernel's API, then stamps that copy's
version.json so the desk pulls it: a desk follows its source's version
file, and any change to it is a release. One GET of the tree with ?as=tree
says what is there and under which mark. A file is made with PUT
/grubbery/api/make/<path>?blot=..., written over with ?force=1, and culled
first when it is there under another mark. It is read back with GET
/grubbery/api/peek/<path> and sent only when it differs. A file the repo
no longer has is culled.

--add makes the desk the first time (POST /apps/grubbery/desks/add,
following /<desk>-dev/code), jailed until approved. A current kernel
boots stock desks (orrery among them) that follow ~ricsul-bilwyt, which a
fake ship cannot reach. --add removes such a desk first with
/desks/delete, but only when it follows that stock source, holds no
instance, and the ship is a galaxy. --replace-desk drops the first two
for a throwaway ship. Without --add, a desk that follows anything else is
refused: it would never pull this deploy.

--approve grants the instance its own weir.json and the groups its
groups.json names (approve-weir with them as `granted`; without `granted`
the kernel grants an empty weir), then reloads its permits. The jar comes
from hoon-test-kit/ship-cookie.sh.

The shell is at /apps/shell on a current kernel; /grubbery/api/peek/apps/
says which spelling this ship has.

Never point this at a real ship: releases go through the forge.
"""
import json, os, re, sys, time, urllib.error, urllib.parse, urllib.request

url, jar = sys.argv[1].rstrip('/'), sys.argv[2]
code = sys.argv[3]
#  another grubbery desk (calendar, auspex) goes on a dev ship the same way
desk = sys.argv[sys.argv.index('--desk') + 1] if '--desk' in sys.argv else 'orrery'
if not re.match(r'https?://(localhost|127\.0\.0\.1)(:\d+)?$', url):
    sys.exit('dev-deploy: refusing a non-local ship; this is for fake ships only')
dest = f'/{desk}-dev/code'
cookie = next(f'{p[5]}={p[6]}' for p in (l.removeprefix('#HttpOnly_').rstrip('\n').split('\t') for l in open(jar))
              if len(p) == 7 and p[5].startswith('urbauth-'))
MITES = {'js': 'application/javascript', 'html': 'text/html', 'css': 'text/css', 'svg': 'image/svg+xml',
         'md': 'text/markdown', 'txt': 'text/plain', 'json': 'application/json', 'hoon': 'text/x-hoon'}


def call(method, path, data=None, ctype=None):
    head = {'cookie': cookie}
    if isinstance(data, str):
        data = data.encode()
    if ctype:
        head['content-type'] = ctype
    req = urllib.request.Request(url + urllib.parse.quote(path, safe='/?=&.~-_'), data=data, method=method, headers=head)
    try:
        with urllib.request.urlopen(req, timeout=600) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def post_json(path, body):
    return call('POST', path, json.dumps(body), 'application/json')


def peek(path):
    return call('GET', '/grubbery/api/peek' + path)


def peek_json(path):
    s, b = peek(path)
    try:
        return json.loads(b) if s == 200 else None
    except ValueError:
        return None


def shell():
    d = None
    for _ in range(150):  # a ship that has just booted answers late
        d = peek_json('/apps/')
        if d is not None:
            break
        time.sleep(2)
    dirs = (d or {}).get('dirs') or []
    for s in ('shell', 'shell.shell'):
        if s in dirs:
            return '/apps/' + s
    sys.exit(f'dev-deploy: no shell under /apps: {d}')


def marks(tree, pre=''):
    """path relative to the tree -> mark, for every grub in a ?as=tree peek"""
    out = {pre + f: m for f, m in (tree.get('files') or {}).items()}
    for d, sub in (tree.get('dirs') or {}).items():
        out.update(marks(sub, pre + d + '/'))
    return out


desk_dir = f'{shell()}/desks/{desk}.desk'
app = f'{desk_dir}/desk/data/{desk}.{desk}_app'
STOCK = {'code': f'~ricsul-bilwyt/apps/shell/desks/{desk}.desk/desk/code'}


def check_desk():
    """None when the desk follows dest already, False when there is none
    and --add makes it, True when --add replaces it. Anything else stops."""
    s, b = peek(desk_dir + '/source.json')
    if s == 404:
        if '--add' not in sys.argv:
            sys.exit(f'dev-deploy: there is no {desk_dir}; run with --add to make it')
        return False
    if s != 200:
        sys.exit(f'dev-deploy: cannot read {desk_dir}/source.json ({s} {b[:200]!r}): left alone')
    src = json.loads(b)
    if src == {'code': dest}:
        return None
    if '--add' not in sys.argv:
        sys.exit(f'dev-deploy: the desk follows {json.dumps(src)}, not {dest}: it would never pull '
                 'this deploy. On a fresh fake ship run with --add')
    held = f'dev-deploy: {desk_dir} follows {json.dumps(src)} and may hold data; left alone'
    if '--replace-desk' not in sys.argv:
        if src != STOCK:
            sys.exit(f'{held}. Only a desk following {json.dumps(STOCK)} is replaced; --replace-desk overrides')
        kids = peek_json(desk_dir + '/desk/data/')
        if kids is None or kids.get('dirs') or kids.get('files'):
            sys.exit(f'{held}. Its data is not empty ({kids}); --replace-desk overrides')
    s, who = call('GET', '/~/host')
    who = who.decode(errors='replace').strip()
    if s != 200 or not re.fullmatch(r'~[a-z]{3}', who):
        sys.exit(f'{held}. Only a galaxy (a fleet or CI ship) has its desk replaced; this is {who}')
    print(f'dev-deploy: replacing {desk_dir}, which follows {json.dumps(src)}')
    return True


replace = check_desk()

#  a file a /< import names is kept as mime, which is what the import
#  finds, whatever its extension (auspex's ui-app/manifest.json)
raw = set()
for dp, _, fs in os.walk(code):
    for f in fs:
        if not f.endswith('.hoon'): continue
        for line in open(os.path.join(dp, f), encoding='utf-8'):
            hit = re.match(r'/<\s+\S+\s+(\S+)', line)
            if hit: raw.add(os.path.normpath(os.path.join(os.path.relpath(dp, code), hit.group(1))))

tree = peek_json(dest + '/?as=tree')
held = marks(tree) if tree else {}


#  under a directory named bundle or *-bundle: source the nexus imports
#  as data (lib/tool-bundle, the tools nexus's seed), which the kernel
#  keeps as mime when a desk syncs, and only a mime is found by the
#  directory import
def bundled(rel):
    return any(d == 'bundle' or d.endswith('-bundle') for d in rel.split('/')[:-1])


#  a .hoon or .json file is kept under its own mark; any other (the icon)
#  as mime, which is what a /< import of it finds, as the forge lays it
def put(rel, text):
    path = f'{dest}/{rel}'
    ext = rel.rsplit('.', 1)[-1]
    mark = ext if ext in ('hoon', 'json') and not (os.path.normpath(rel) in raw and ext != 'hoon') else 'mime'
    if bundled(rel): mark = 'mime'
    args = [] if mark == 'mime' else [f'blot=/{mark}']
    have = held.get(rel)
    if have is not None and have != mark:
        s, b = call('DELETE', '/grubbery/api/cull' + path)
        if s != 200: sys.exit(f'cull {path}: {s} {b[:200]}')
        have = None
    #  a redeploy sends only what changed (json is re-rendered, so always sent)
    if have is not None and mark != 'json' and peek(path) == (200, text.encode()):
        return False
    if have is not None:
        args.append('force=1')
    q = '?' + '&'.join(args) if args else ''
    s, b = call('PUT', '/grubbery/api/make' + path + q, text, MITES.get(ext, 'application/octet-stream'))
    if s not in (200, 201): sys.exit(f'make {path}: {s} {b.decode(errors="replace")[:400]}')
    return True


files = sorted(os.path.relpath(os.path.join(dp, f), code)
               for dp, _, fs in os.walk(code) for f in fs)
for rel in files:
    if rel == 'version.json': continue
    if put(rel, open(os.path.join(code, rel), encoding='utf-8').read()):
        print('  ' + rel)
#  what the repo no longer has goes too, or the desk keeps building it
for rel in sorted(set(held) - set(files)):
    s, b = call('DELETE', f'/grubbery/api/cull{dest}/{rel}')
    print(f'  - {rel}: {s}')
#  last, so the desk pulls a whole tree: the repo's version, stamped
ver = json.load(open(os.path.join(code, 'version.json')))
ver['dev'] = time.strftime('%Y-%m-%dT%H:%M:%S')
put('version.json', json.dumps(ver))
print(f'  version.json {json.dumps(ver)}')

if replace:
    s, b = post_json('/apps/grubbery/desks/delete', {'app': f'{desk}.desk'})
    print(f'desks/delete: {s} {b.decode(errors="replace")}')
    if s != 200: sys.exit(1)
    for _ in range(60):  # the cull lands a moment after the answer
        if peek(desk_dir + '/source.json')[0] == 404: break
        time.sleep(1)
if replace is not None:
    s, b = post_json('/apps/grubbery/desks/add', {'name': desk, 'code': dest})
    print(f'desks/add: {s} {b.decode(errors="replace")}')
    if s != 200: sys.exit(1)

if '--approve' in sys.argv:
    for _ in range(180):  # the instance appears once the desk has built (~7 min)
        s, weir = peek(f'{app}/weir.json')
        if s == 200 and weir.strip(): break
        time.sleep(5)
    else:
        sys.exit(f'dev-deploy: no {app}/weir.json yet; run --approve again later')
    granted = json.loads(weir)
    groups = peek_json(f'{app}/groups.json')
    if isinstance(groups, dict):
        granted['groups'] = sorted(groups)
    grant = {'action': 'approve-weir', 'app': app, 'picks': {}, 'granted': granted}
    for path, body in (('/apps/grubbery/permits', grant), ('/apps/grubbery/permits/reload', {'app': app})):
        s, b = post_json(path, body)
        print(f'{path}: {s}')
        if s not in (200, 303): sys.exit(b[:400].decode(errors='replace'))
