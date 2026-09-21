#!/usr/bin/env python3
"""prompt-drift: the lib's prompt cords are the shared files, byte for byte,
and the decider's question instructions are analyze.py's, word for word.

    python3 scripts/prompt-drift.py ../orrery-utils/common
"""
import re
import sys

utils = sys.argv[1].rstrip('/')
lib = open('code/lib/orrery.hoon').read()
PAIRS = [('system-prompt', 'generator-prompt.md'), ('analyst-prompt', 'analyst-prompt.md'), ('refine-prompt', 'refine-prompt.md')]
#  the decider's questions: each question's instructions string in
#  analyze.py, and each of its criteria, must appear in the lib as a cord
QUESTIONS = ['worth_reading', 'needs_help_now', 'status_%d']


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
analyze = open(utils + '/analyze.py').read()


def in_lib(text):
    #  the status question names its proposal: only the text before the
    #  first % is fixed
    fixed = text.split('%')[0] if '%' in text else text
    return ("'%s" % fixed.replace("'", "\\'") + ("" if '%' in text else "'")) in lib


for q in QUESTIONS:
    m = re.search(r"'%s'(?: %% i)?: \{\s*'type': '\w+',\s*'instructions': '([^']*)'.*?,\s*'criteria': (\{[^}]*\}|STATUS_CRITERIA)" % re.escape(q), analyze, re.S)
    if not m:
        raise SystemExit('no question ' + q + ' in analyze.py')
    crit = m.group(2)
    if crit == 'STATUS_CRITERIA':
        crit = re.search(r"STATUS_CRITERIA = (\{[^}]*\})", analyze).group(1)
    texts = [m.group(1)] + re.findall(r"'\w+': '([^']*)'", crit)
    missing = [t for t in texts if not in_lib(t)]
    if missing:
        bad += 1
        print('DRIFT question %s: %s' % (q, '; '.join(missing)))
    else:
        print('ok   question %s (%d strings)' % (q, len(texts)))
sys.exit(1 if bad else 0)
