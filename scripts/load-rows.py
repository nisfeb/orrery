#!/usr/bin/env python3
"""load-rows.py: every file the app writes at its root has a row in
+on-load. The loader drops at every load whatever no row declares
(grubbery's lib/loader.hoon: "Anything not listed is dropped"), so a
file written without one is lost at the next update or reload: until
version 97 that was search.json, search-last.json and sphere-trust.json,
and ricsul's owner lost a Brave key to it. Exits 1 naming each one.

    python3 scripts/load-rows.py
"""
import re, sys

src = open('code/nex/orrery/app.hoon').read()
start = src.index('++  on-load')
block = src[start:src.index('\n    ++  ', start + 10)]
declared = set(re.findall(r"\[/ %'([a-z0-9-]+\.json)'\]", block))
# a write names its file on the same line as over:io, or on the next
# one in the tall form; a helper handed a file name writes it too
written = set(re.findall(r"over:io\s+\(rf [01] / %'([a-z0-9-]+\.json)'\)", src))
written |= set(re.findall(r"\((?:do-set-merged jon|do-set-doc) %'([a-z0-9-]+\.json)'", src))
missing = sorted(written - declared)
for f in missing:
    print('written, never declared in +on-load: ' + f)
print('%d files written, %d declared, %d missing' % (len(written), len(declared), len(missing)))
sys.exit(1 if missing else 0)
