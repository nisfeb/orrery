#!/usr/bin/env python3
"""page-smoke.py HOST JAR
The page is served to the owner with the right types and no cache, and
refused without the cookie; then the render tests run under node.
Exits 1 on any failure."""
import os, subprocess, sys

HOST, JAR = sys.argv[1:3]
fails = []
count = [0]


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


def check(label, cond, detail=''):
    count[0] += 1
    print(('  ok   ' if cond else '  FAIL ') + label + ('' if cond else '   ' + str(detail)[:300]))
    if not cond:
        fails.append(label)


code, h, b = get('/apps/orrery')
check('the page answers 200 as html', code == 200 and h.get('content-type', '').startswith('text/html'), (code, h))
check('the page is not cached', 'no-cache' in h.get('cache-control', ''), h)
check('the page loads its script and style', 'orrery.js' in b and 'orrery.css' in b and 'id="view"' in b, b[:200])
code, h, b = get('/apps/orrery/orrery.js')
check('the script answers as javascript', code == 200 and 'javascript' in h.get('content-type', '') and '/apps/orrery/api' in b, (code, h))
code, h, b = get('/apps/orrery/orrery.css')
check('the style answers as css', code == 200 and h.get('content-type', '').startswith('text/css'), (code, h))
code, h, b = get('/apps/orrery/nope.txt')
check('an unknown file is 404', code == 404, (code, b[:100]))
code, h, b = get('/apps/orrery', jar=False)
check('the page is refused without the cookie', code == 403, (code, b[:100]))
r = subprocess.run(['node', os.path.join(os.path.dirname(os.path.abspath(__file__)), 'page-test.js')], capture_output=True, text=True)
print(r.stdout.rstrip())
check('the render tests pass under node', r.returncode == 0 and 'ALL OK' in r.stdout, r.stderr[:300])
if fails:
    print('FAILED: ' + ', '.join(fails))
    sys.exit(1)
print('ALL OK (%d checks)' % count[0])
