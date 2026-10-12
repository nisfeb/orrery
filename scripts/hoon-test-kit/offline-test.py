#!/usr/bin/env python3
"""Run a test file's test- arms through `vere eval`, with no ship.

A fast inner loop for pure libs: vere eval has hoon and zuse but no clay,
scries or agents, so this splices each import in by hand, each lib built
once and bound for every lib that imports it. Run it from
the app repo, where hoon-test.conf lives. The verdict that counts is still
hoon-test.sh on a fake ship.

usage: offline-test.py tests/lib/foo.hoon [arm ...]

Each /+ import NAME is found, in order, in:
  1. hoon-test.conf's FILES (an entry SRC=lib/NAME.hoon) and LIBS
     (an entry ending in NAME.hoon),
  2. ./lib/NAME.hoon, ./lib/A/B.hoon for NAME a-b, the same under CODE,
     then ./vendor/NAME.hoon,
  3. a mounted %base: $BASE_DIR, else the dev platform ship's
     ~/fleet/piers/*/base (for test.hoon and other stock libs).
A /- import is found the same way under sur/. Imports inside the libs are
followed too. With DIALECT=grubbery in hoon-test.conf, a lib's
/<  face  /lib/x.hoon (absolute, or relative to the lib) is read under
CODE, /&  face  /lib/dir/ binds the directory's files as the
(axal (map @ta mime)) grubbery hands over, and each PRELUDE name (found
like a /+) is a face in every lib's subject.
OFFLINE_LIB_NAME=path overrides one import, e.g. OFFLINE_LIB_unix=x.hoon.
"""
import glob, os, re, shlex, subprocess, sys

VERE = os.environ.get('VERE') or sorted(
    glob.glob(os.path.expanduser('~/software/vere-*-linux-x86_64')),
    key=lambda p: [int(x) for x in re.findall(r'\d+', os.path.basename(p))])[-1]


def conf():
    """hoon-test.conf's shell-style assignments, as a dict."""
    out = {}
    if os.path.exists('hoon-test.conf'):
        for line in open('hoon-test.conf'):
            m = re.match(r'\s*([A-Z_]+)=(.*)$', line)
            if m:
                out[m.group(1)] = ' '.join(shlex.split(m.group(2), comments=True))
    return out


def bases():
    if os.environ.get('BASE_DIR'):
        return [os.environ['BASE_DIR']]
    # the dev platform first, then any other mounted fleet pier
    found = sorted(glob.glob(os.path.expanduser('~/fleet/piers/*/base')))
    return sorted(found, key=lambda p: '/pex/' not in p)


def find(name, c, sur=False):
    env = os.environ.get('OFFLINE_LIB_' + name.replace('-', '_'))
    if env and not sur:
        return env
    top = 'sur' if sur else 'lib'
    if not sur:
        for entry in c.get('FILES', '').split():
            src, _, dest = entry.partition('=')
            if os.path.basename(dest or src) == name + '.hoon':
                return src
        for src in c.get('LIBS', '').split():
            if os.path.basename(src) == name + '.hoon':
                return src
    # ford's own search: lib/a-b.hoon, then lib/a/b.hoon; under CODE too
    # (a grubbery desk's tree)
    roots = ['.'] + ([c['CODE']] if c.get('CODE') else [])
    rels = [f'{name}.hoon']
    if '-' in name:
        rels.append(name.replace('-', '/') + '.hoon')
    cands = [os.path.join(r, top, x) for r in roots for x in rels]
    if not sur:
        cands.append(f'vendor/{name}.hoon')
    cands += [os.path.join(b, top, x) for b in bases() for x in rels]
    for p in cands:
        if os.path.exists(p):
            return p
    rune = '/-' if sur else '/+'
    sys.exit(f'offline-test: no source for {rune} {name}; set OFFLINE_LIB_{name.replace("-", "_")}=path')


GRUB = re.compile(r'^/<\s+(\*|[a-z][a-z0-9-]*)\s+(\S+)\s*$')
GMIME = re.compile(r'^/&\s+([a-z][a-z0-9-]*)\s+(\S+)\s*$')


def cord(data):
    """bytes -> a hoon cord literal."""
    out = []
    for b in data:
        ch = chr(b)
        if ch in "\\'" or b < 0x20 or b > 0x7e:
            out.append('\\%02x' % b)
        else:
            out.append(ch)
    return "'" + ''.join(out) + "'"


class Build:
    """Every lib the suite reaches, each compiled once, in import order.

    A lib's imports become faces bound to earlier libs: /+ and /- as ford
    reads them, and with DIALECT=grubbery /< (a lib by its path) and /&
    (a directory of files as the (axal (map @ta mime)) grubbery hands
    over), with PRELUDE's faces in every lib's subject."""

    def __init__(self, c):
        self.c, self.done, self.out = c, {}, []
        self.grub = c.get('DIALECT') == 'grubbery'
        self.code = c.get('CODE', '.')
        self.prelude = c.get('PRELUDE', '').split() if self.grub else []
        self.prelude_libs = []

    def lib(self, path):
        """bind the lib at path once; answer its face in the subject"""
        key = os.path.normpath(path)
        if key in self.done:
            return self.done[key] or sys.exit(f'offline-test: import cycle at {path}')
        self.done[key] = None
        text = self.expr(open(path).read(), os.path.dirname(path), lib=True)
        face = f'ol-{len(self.out)}'
        self.out.append(f'=/  {face}\n{text}')
        self.done[key] = face
        return face

    def mime_dir(self, path):
        names = sorted(f for f in os.listdir(path) if os.path.isfile(os.path.join(path, f)))
        rows = ' '.join(f"[~.{n} (mk {cord(open(os.path.join(path, n), 'rb').read())})]"
                        if re.match(r'^[a-z0-9~_.-]+$', n) else sys.exit(f'{n}: not a knot')
                        for n in names)
        return ('=/  mk  |=(c=@t `mime`[/text/plain (met 3 c) c])\n'
                f'^-  (axal (map @ta mime))\n[`(malt `(list [@ta mime])`~[{rows}]) ~]')

    def expr(self, src, here, lib):
        """src with its import runes replaced by faces bound to built libs"""
        lines, binds, n = src.split('\n'), [], 0
        if lib:
            for p in self.prelude_libs:
                binds.append(p)
        for n, line in enumerate(lines):
            s = line.strip()
            if not s or s.startswith('::') or s.startswith('/?'):
                continue
            if s.startswith('/+') or s.startswith('/-'):
                sur = s.startswith('/-')
                for item in (x.strip() for x in s[2:].split(',') if x.strip()):
                    star = item.startswith('*')
                    face, _, name = item.lstrip('*').partition('=')
                    f = self.lib(find(name or face, self.c, sur))
                    binds.append(f'=+  {f}' if star else f'=/  {face}  {f}')
                continue
            m = self.grub and GRUB.match(s)
            if m:
                face, p = m.groups()
                if not p.startswith('/'):
                    p = '/' + os.path.normpath(os.path.join(os.path.relpath(here, self.code), p))
                f = self.lib(os.path.join(self.code, p.strip('/')))
                binds.append(f'=+  {f}' if face == '*' else f'=/  {face}  {f}')
                continue
            m = self.grub and GMIME.match(s)
            if m and m.group(2).startswith('/') and m.group(2).endswith('/'):
                binds.append(f'=/  {m.group(1)}\n' + self.mime_dir(
                    os.path.join(self.code, m.group(2).strip('/'))))
                continue
            if s.startswith('/') and len(s) > 1 and s[1] in '$%*=~&<':
                sys.exit(f'offline-test: {s.split()[0]} is not supported offline')
            break
        return '\n'.join(binds + lines[n:])


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    path, only = sys.argv[1], sys.argv[2:]
    c = conf()
    b = Build(c)
    for name in b.prelude:
        f = b.lib(find(name, c))
        b.prelude_libs.append(f'=/  {name}  {f}')
    body = b.expr(open(path).read(), os.path.dirname(path), lib=False)
    arms = re.findall(r'^\+\+  (test-[\w-]+)', body, re.M)
    if only:
        arms = [a for a in arms if a in only]
    pre = b.out
    calls = '\n'.join(f'    [%{a} (mule |.({a}:t))]' for a in arms)
    hoon = '\n'.join(pre) + '\n=/  t\n' + body + f'''
%+  turn
  ^-  (list [term (each tang tang)])
  :~
{calls}
  ==
|=  [n=term r=(each tang tang)]
^-  [term ? wall]
?:  ?=(%| -.r)
  [n | (zing (turn (flop p.r) (cury wash [0 100])))]
[n =(~ p.r) (zing (turn p.r (cury wash [0 100])))]
'''
    if os.environ.get('DUMP'):
        open(os.environ['DUMP'], 'w').write(hoon)
    out = subprocess.run([VERE, 'eval'], input=hoon.encode(), capture_output=True)
    clean = lambda b: re.sub(r'\x1b\[[0-9;]*m', '', b.decode())
    noise = re.compile(r'^(loom:|lite:|eval \(run\):)')
    log = [l for l in clean(out.stderr).splitlines() if not noise.match(l)]
    res = clean(out.stdout)
    print('\n'.join(log))
    print('\n'.join(l for l in res.splitlines() if '%.y <<>>' not in l))
    ok, bad = res.count('%.y <<>>'), res.count('%.n <<')
    print(f'{ok} passed, {bad} failed, of {len(arms)}')
    sys.exit(0 if arms and ok == len(arms) else 1)


main()
