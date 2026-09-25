#!/usr/bin/env python3
"""Mutation check for the Hoon libs: break one thing, run the suites, and
report every break that no test noticed. See README.md and PLAYBOOK.md.

    hoon-mutate.py <pier> [--ops OP,...] [--only ARM,...] [--since REV] [--list]

Each mutant is written into the test desk's mount, never into the repo, and
the clean lib is synced back when the run ends, however it ends. A mutant
that loops forever is interrupted with SIGINT to the ship's king process,
exactly what ^C in its dojo does.
"""
import argparse, os, re, shlex, signal, subprocess, sys, time

KIT = os.path.dirname(os.path.abspath(__file__))


def find_conf():
    """hoon-test.conf, as hoon-test.sh finds it: $HOON_TEST_CONF, or the
    nearest one at or above the current directory."""
    if os.environ.get('HOON_TEST_CONF'):
        return os.path.abspath(os.environ['HOON_TEST_CONF'])
    d = os.getcwd()
    while True:
        if os.path.isfile(f'{d}/hoon-test.conf'):
            return f'{d}/hoon-test.conf'
        if d == '/':
            sys.exit('no hoon-test.conf here or above')
        d = os.path.dirname(d)


def read_conf(path):
    """The KEY=value lines of a conf file bash also sources."""
    conf = {}
    for tok in shlex.split(open(path).read(), comments=True):
        if '=' in tok:
            k, v = tok.split('=', 1)
            conf[k] = v
    return conf


CONF = find_conf()
ROOT = os.path.dirname(CONF)
_c = read_conf(CONF)
DESK = _c['DESK']
LIBS = [(f'{ROOT}/{p}', os.path.basename(p)[:-len('.hoon')]) for p in _c['LIBS'].split()]
SWAP = {'lte': 'lth', 'lth': 'lte', 'gte': 'gth', 'gth': 'gte'}


def code_part(line):
    i = line.find('::')
    return line if i < 0 else line[:i]


def arm_at(lines, n):
    for i in range(n, -1, -1):
        m = re.match(r'\s*\+[+$*]  (\S+)', lines[i])  # an arm, a mold or an alias
        if m:
            return m.group(1)
    return '?'


def boundary(lines):
    """(lte a b) <-> (lth a b), (gte a b) <-> (gth a b): the edge case."""
    for n, line in enumerate(lines):
        for m in re.finditer(r'\((lte|lth|gte|gth) ', code_part(line)):
            op = m.group(1)
            new = line[:m.start() + 1] + SWAP[op] + line[m.end() - 1:]
            yield n, f'{op}->{SWAP[op]}', {n: new}


def conjunct(lines):
    """One child of a tall ?& (or ?|) replaced by its identity, & (or |):
    the guard as if that condition were never written."""
    for n, line in enumerate(lines):
        m = re.match(r'(\s*)(\?&|\?\|)  (?=\S)', code_part(line))
        if not m:
            continue
        rune, col = m.group(2), m.end()
        unit = '&' if rune == '?&' else '|'
        end = n + 1  # the closing == at the rune's own column
        while end < len(lines) and not lines[end].startswith(m.group(1) + '=='):
            end += 1
        starts = [n] + [i for i in range(n + 1, end)
                        if len(lines[i]) - len(lines[i].lstrip()) == col and lines[i].strip()
                        and not lines[i].lstrip().startswith('::')]
        for k, s in enumerate(starts):
            stop = starts[k + 1] if k + 1 < len(starts) else end
            edit = {i: None for i in range(s, stop)}  # None: drop the line
            head = lines[s][:col] if s == n else ' ' * col
            edit[s] = head + unit + '\n'
            child = (lines[s][col:] if s == n else lines[s].strip()).strip()
            yield s, f'{rune} drop {child[:40]}', edit


def swapper(pattern, table, label):
    """Every match of `pattern` in code (not comments) replaced by its
    table entry, one site per mutant."""
    def op(lines):
        for n, line in enumerate(lines):
            code = code_part(line)
            for m in re.finditer(pattern, code):
                old = m.group(0)
                new = line[:m.start()] + table[old] + line[m.end():]
                yield n, f'{label} {old.strip()}->{table[old].strip()}', {n: new}
    op.__name__ = label
    return op


# ?: and ?. swapped: the branch taken when the condition does not hold.
branch = swapper(r'\?[:.](?=  |\()', {'?:': '?.', '?.': '?:'}, 'branch')
# =( and !=( swapped, and only as a comparison: after a space or a bracket,
# never ?=( (a type test) and never the =( inside a rune like |=( or ^=(.
equal = swapper(r'(?:(?<=[\s(\[])|^)!?=\(', {'=(': '!=(', '!=(': '=('}, 'equal')
# a literal flag flipped: a default or an early answer nobody relies on.
flag = swapper(r'%\.[yn]\b', {'%.y': '%.n', '%.n': '%.y'}, 'flag')

MENU = {op.__name__: op for op in [boundary, conjunct, branch, equal, flag]}


def touched_arms(rev):
    """The arms a git diff against rev touches, per lib: where a big lib's
    change is, so the expensive ops run there and not over every arm."""
    arms = set()
    for path, lib in LIBS:
        diff = subprocess.run(['git', '-C', ROOT, 'diff', '-U0', rev, '--', path],
                              capture_output=True, text=True, check=True).stdout
        lines = open(path).readlines()
        for m in re.finditer(r'^@@ -\S+ \+(\d+)(?:,(\d+))? @@', diff, re.M):
            start, count = int(m.group(1)), int(m.group(2) or 1)
            for n in range(max(start - 1, 0), min(start - 1 + max(count, 1), len(lines))):
                arms.add((lib, arm_at(lines, n)))
    return arms


def mutants(menu):
    for path, lib in LIBS:
        lines = open(path).readlines()
        for op in menu:
            for n, what, edit in op(lines):
                out = [edit.get(i, l) for i, l in enumerate(lines)]
                yield lib, n + 1, arm_at(lines, n), what, ''.join(l for l in out if l is not None)


def king_pid(pier):
    name = os.path.basename(os.path.abspath(pier))
    for pid in filter(str.isdigit, os.listdir('/proc')):
        try:
            argv = open(f'/proc/{pid}/cmdline', 'rb').read().split(b'\0')
        except OSError:
            continue
        args = [a.decode(errors='replace') for a in argv if a]
        if args and 'vere' in args[0] and 'work' not in args[1:2] and name in args[1:2]:
            return int(pid)


def run(pier, env=None, timeout=None):
    return subprocess.run([f'{KIT}/hoon-test.sh', pier],
                          env={**os.environ, 'HOON_TEST_CONF': CONF, **(env or {})},
                          capture_output=True, text=True, timeout=timeout)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('pier')
    ap.add_argument('--only', help='comma-separated arm names')
    ap.add_argument('--since', metavar='REV',
                    help='only the arms a git diff against REV touches (a branch, a tag, HEAD)')
    ap.add_argument('--list', action='store_true', help='print the mutants and stop')
    ap.add_argument('--ops', default='boundary,conjunct',
                    help=f'comma-separated, from: {",".join(MENU)} (default: %(default)s)')
    a = ap.parse_args()
    only = set(a.only.split(',')) if a.only else None
    touched = touched_arms(a.since) if a.since else None
    todo = [m for m in mutants([MENU[o] for o in a.ops.split(',')])
            if (not only or m[2] in only) and (touched is None or (m[0], m[2]) in touched)]
    if a.list:
        for lib, line, arm, what, _ in todo:
            print(f'{lib}:{line}  +{arm}  {what}')
        print(f'{len(todo)} mutants')
        return
    if run(a.pier).returncode != 0:
        sys.exit('the suites fail on the clean libs; fix that first')
    tally, survivors = {}, []
    try:
        for i, (lib, line, arm, what, text) in enumerate(todo, 1):
            with open(f'{a.pier}/{DESK}/lib/{lib}.hoon', 'w') as f:
                f.write(text)
            t0 = time.time()
            r = run(a.pier, {'NOSYNC': '1', 'TEST_T': '120'})
            if r.returncode == 4:  # no answer: the ship is down, stop here
                print(f'[{i}/{len(todo)}] the ship stopped answering during {lib}:{line} +{arm} {what}; '
                      'results from here are void', flush=True)
                break
            verdict = {0: 'SURVIVED', 1: 'killed', 3: 'no-build'}.get(r.returncode, 'timeout')
            if verdict == 'timeout':
                pid = king_pid(a.pier)
                if pid:
                    os.kill(pid, signal.SIGINT)  # ^C: ends the looping event
                time.sleep(5)
            tally[verdict] = tally.get(verdict, 0) + 1
            if verdict == 'SURVIVED':
                survivors.append((lib, line, arm, what))
            print(f'[{i}/{len(todo)}] {verdict:8} {lib}:{line} +{arm} {what} ({time.time() - t0:.0f}s)', flush=True)
    finally:
        # Write the clean libs AND force the commit. A sync alone is not
        # enough: if the mount already matches the repo, rsync reports no
        # change and the desk keeps the last mutant it committed.
        for path, lib in LIBS:
            with open(path) as src, open(f'{a.pier}/{DESK}/lib/{lib}.hoon', 'w') as dst:
                dst.write(src.read())
        if run(a.pier, {'NOSYNC': '1'}).returncode != 0:
            print('could not restore the clean libs on the ship; once it is up, run '
                  'NOSYNC=1 hoon-test.sh <pier>')
    print('\n' + '  '.join(f'{k}: {v}' for k, v in sorted(tally.items())))
    for lib, line, arm, what in survivors:
        print(f'SURVIVED  {lib}:{line}  +{arm}  {what}')


if __name__ == '__main__':
    main()
