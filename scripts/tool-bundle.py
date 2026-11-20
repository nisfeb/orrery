#!/usr/bin/env python3
"""tool-bundle.py [--check]: lay the libs the MCP tools import into
code/lib/tool-bundle, beside the tools.

The instance seeds its tools nexus from that directory (+tools-mount in
the nexus). A directory named *-bundle is kept as mime on the ship, so
the nexus can import it as source; the rest of /lib is compiled, and a
directory import gathers mime only. The tools import three libs the
nexus also compiles, so those three are copies, and this keeps them
equal. With --check it changes nothing and exits 1 on any difference.
"""
import filecmp, shutil, sys

LIBS = ('tools.hoon', 'orrery.hoon', 'orrery-mcp.hoon')
check = '--check' in sys.argv
bad = 0
for n in LIBS:
    src, dst = 'code/lib/' + n, 'code/lib/tool-bundle/' + n
    try:
        same = filecmp.cmp(src, dst, shallow=False)
    except FileNotFoundError:
        same = False
    if same:
        continue
    if check:
        print('differs from its source: ' + dst)
        bad += 1
    else:
        shutil.copyfile(src, dst)
        print('copied ' + src)
sys.exit(1 if bad else 0)
