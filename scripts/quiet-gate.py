#!/usr/bin/env python3
"""quiet-gate.py TMUX-TARGET HOST JAR
The quiet gate of docs/logging.md, the part a script can run: the
ship's console is captured from its tmux pane, orrery's instance is
reloaded through the explorer, the console is captured again once the
instance is back, and every new line that is not on the known-noise
register is a finding. Exits 1 on any finding, or when the instance
does not come back. The gate's other steps (an upgrade with real data,
a refused permission, the grant that clears it) change the ship's
permits and stay the operator's, by hand, from the same table."""
import re, subprocess, sys, time, urllib.parse, urllib.request

TARGET, HOST, JAR = sys.argv[1:4]
INSTANCE = HOST + '/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app'

#  lines the kernel or the runtime print on their own, reported upstream
#  and listed in docs/logging.md so an old line can be told from a new one
KNOWN_NOISE = [
    r'%desk-source-unreachable',
    r'^eyre: replacing existing binding at /apps/orrery$',
    r'^http: fail \(\d+, \d+\): ',
]
PROMPT = re.compile(r'^\s*~[a-z-]+:dojo>')


def console():
    #  -J joins the lines the pane wrapped; the prompt is redrawn at the
    #  bottom after every print, so it is no part of what the ship said
    out = subprocess.run(['tmux', 'capture-pane', '-p', '-J', '-S', '-', '-t', TARGET], capture_output=True, text=True).stdout
    lines = [re.sub(r'\x1b\[[0-9;]*[A-Za-z]', '', l).rstrip() for l in out.splitlines()]
    return [l for l in lines if l.strip() and not PROMPT.match(l)]


def cookie():
    for line in open(JAR):
        parts = line.split('\t')
        if len(parts) >= 7 and parts[5].startswith('urbauth'):
            return parts[5] + '=' + parts[6].strip()
    sys.exit('no urbauth cookie in ' + JAR)


def http(method, url, data=None):
    req = urllib.request.Request(url, data=data, method=method, headers={'Cookie': cookie()})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode()


before = console()
http('POST', INSTANCE, urllib.parse.urlencode({'action': 'reload-nexus'}).encode())
deadline = time.time() + 180
back = False
while time.time() < deadline:
    time.sleep(5)
    try:
        info = http('GET', INSTANCE + '?info=1')
        if '"bang": null' in info or '"bang":null' in info:
            back = True
            break
    except Exception:
        pass
time.sleep(10)
after = console()
#  what the pane gained: everything after the last place the old tail
#  ends in the new capture (the scrollback may have dropped old lines off
#  its top, so the two are matched from the end, on a run of lines)
tail = before[-30:]
at = None
for i in range(len(after) - len(tail), -1, -1):
    if after[i:i + len(tail)] == tail:
        at = i + len(tail)
        break
if at is None:
    print('FAIL the console before the reload is not found in the console after it: nothing can be said')
    sys.exit(2)
new = after[at:]
findings = [l for l in new if not any(re.search(p, l) for p in KNOWN_NOISE)]
for l in new:
    print(('FINDING ' if l in findings else 'ignored ') + l)
print(('instance back' if back else 'FAIL instance did not come back') + ', %d new console line(s), %d finding(s)' % (len(new), len(findings)))
sys.exit(0 if back and not findings else 1)
