#!/usr/bin/env python3
"""page-smoke.py HOST JAR
The page is served to the owner with the right types and no cache, and
refused without the cookie; the beacon stream the page reads for live
updates answers; then the render tests run under node. Exits 1 on any
failure."""
import os, re, subprocess, sys
from gate import fails, count, check

HOST, JAR = sys.argv[1:3]


def get(path, jar=True):
    cmd = ['curl', '-s', '-m', '30', '-D', '-', '-o', '/dev/stdout', HOST + path]
    if jar:
        cmd += ['-b', JAR]
    out = subprocess.run(cmd, capture_output=True, text=True).stdout
    head, _, body = out.partition('\r\n\r\n')
    if not _:
        head, _, body = out.partition('\n\n')
    code = int(head.split(' ')[1]) if head.startswith('HTTP/') else 0
    headers = {}
    for ln in head.split('\n')[1:]:
        k, _, v = ln.partition(':')
        headers[k.strip().lower()] = v.strip()
    return code, headers, body


code, h, b = get('/apps/orrery')
check('the page answers 200 as html', code == 200 and h.get('content-type', '').startswith('text/html'), (code, h))
check('the page is not cached', 'no-cache' in h.get('cache-control', ''), h)
check('the page loads its script and style', 'orrery.js' in b and 'orrery.css' in b and 'id="view"' in b, b[:200])
code, h, js = get('/apps/orrery/orrery.js')
check('the script answers as javascript', code == 200 and 'javascript' in h.get('content-type', '') and '/apps/orrery/api' in js, (code, h))
code, h, b = get('/apps/orrery/orrery.css')
check('the style answers as css', code == 200 and h.get('content-type', '').startswith('text/css'), (code, h))
code, h, b = get('/apps/orrery/nope.txt')
check('an unknown file is 404', code == 404, (code, b[:100]))
code, h, b = get('/apps/orrery', jar=False)
check('the page is refused without the cookie', code == 403, (code, b[:100]))
code, h, b = get('/apps/orrery/orrery.js', jar=False)
check('the script is refused without the cookie', code == 403, (code, b[:100]))
code, h, b = get('/apps/orrery/orrery.css', jar=False)
check('the style is refused without the cookie', code == 403, (code, b[:100]))

# the beacon stream the page's live updates hang on, read from the
# served script so the gate follows the page rather than a copy of it
m = re.search(r"var KEEP = '([^']+)'", js)
check('the script names the beacon stream', bool(m), js[:200])
# a miss on the KEEP regex leaves ev empty, so the two stream checks
# fail loudly rather than vanishing from the count
ev = ''
if m:
    ev = subprocess.run(['curl', '-s', '-N', '-m', '15', '-b', JAR,
                         '-H', 'accept: text/event-stream', HOST + m.group(1)],
                        capture_output=True, text=True).stdout
lines = [ln.strip() for ln in ev.split('\n')]
check('the stream names a rev event', any(ln.startswith('event: ') and ln.endswith('/rev') for ln in lines), ev[:200])
check('the stream carries the rev as digits', any(ln.startswith('data: ') and ln[6:].strip().isdigit() for ln in lines), ev[:200])

r = subprocess.run(['node', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'page-test.js')], capture_output=True, text=True)
print(r.stdout.rstrip())
check('the render tests pass under node', r.returncode == 0 and 'ALL OK' in r.stdout, r.stderr[:300])
if fails:
    print('FAILED: ' + ', '.join(fails))
    sys.exit(1)
print('ALL OK (%d checks)' % count[0])
