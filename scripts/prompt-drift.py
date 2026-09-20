#!/usr/bin/env python3
"""prompt-drift: the lib's prompt cords are the shared files, byte for byte.

    python3 scripts/prompt-drift.py ../orrery-utils/common
"""
import re
import sys

utils = sys.argv[1].rstrip('/')
lib = open('code/lib/orrery.hoon').read()
PAIRS = [('system-prompt', 'generator-prompt.md'), ('analyst-prompt', 'analyst-prompt.md')]


def cord_of(arm):
    m = re.search(r"\n\+\+  %s\n  \^-  @t\n  '''\n(.*?\n)  '''\n" % re.escape(arm), lib, re.S)
    if not m:
        raise SystemExit('no cord for ' + arm)
    lines = m.group(1).split('\n')
    out = []
    for line in lines:
        if line == '':
            out.append('')
        elif line.startswith('  '):
            out.append(line[2:])
        else:
            raise SystemExit('bad indent in cord for ' + arm)
    return '\n'.join(out)


def normalize(text):
    lines = [line.rstrip() for line in text.split('\n')]
    while lines and lines[-1] == '':
        lines.pop()
    return '\n'.join(lines)


bad = 0
for arm, name in PAIRS:
    want = normalize(open('%s/%s' % (utils, name)).read())
    got = normalize(cord_of(arm))
    if got != want:
        bad += 1
        print('DRIFT %s != %s' % (arm, name))
    else:
        print('ok   %s == %s' % (arm, name))
sys.exit(1 if bad else 0)
