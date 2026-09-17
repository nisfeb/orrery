# Kernel patch: MCP discovery walks the shell's desks

The kernel finds an app's tools by scanning `/apps/<app>/desk/code/lib/tools`, which predates
desks living under the shell at `/apps/shell.shell/desks/<name>.desk/desk/code`. Orrery's tools
are callable by absolute path without this patch. With it they are discovered under
`apps/orrery.desk` and callable by name.

Three places in the kernel walk `/apps`, each with its own copy of the scan, and the patch fixes
all three. Fixing only one is not enough: the first feeds discovery, the other two are the meta
tools an MCP client actually reaches a tool through.

| file | arm or loop | what it feeds |
|---|---|---|
| `desk/gub/nex/mcp.hoon` | `+get-app-mcp-paths` | `+gather-tools-tree` (`/grubbery/mcp/api/tools-tree`) and `+find-tool-src` (`/grubbery/mcp/api/src`) |
| `desk/gub/lib/tool-bundle/tools/call-tool.hoon` | the `Try app namespaces` loop | the `call_tool` meta tool, how a client runs a tool by name |
| `desk/gub/lib/tool-bundle/tools/list-tools.hoon` | the `App namespace tools` loop | the `list_tools` meta tool's listing |

Each gains the same second pass: peek `/apps/'shell.shell'/desks`, turn its children into
`/apps/shell.shell/desks/<desk>/desk/code/lib/tools`, and weld that onto the app list. The two
bundle tools iterated over a `(list @ta)` of `/apps` children and built a path per child; they now
iterate over the `(list path)` of code directories directly, so the two sources of directories
join cleanly. In `nex/mcp.hoon` the second hunk also teaches the discovery loop's name derivation
that a desk path names `apps/<desk>`, so two desks never collide.

`+weld` casts its product to the type of its second argument, so each desk `+turn` needs an
explicit `^-  (list path)` over it or the weld is a `nest-fail`.

## Applying it

```bash
cd /path/to/grubbery
git apply /path/to/orrery/docs/kernel/mcp-desk-tools.patch
```

Then release with the dist branch. `git apply --check` against the grubbery checkout passes as of
this commit.

## What changes, and what does not

After the patch, on a ship with orrery installed:

- `GET /grubbery/mcp/api/tools-tree` grows a directory `apps/orrery.desk` holding the eight
  orrery tools. The root registry is untouched.
- `list_tools` counts and names them.
- `call_tool` runs one by name: `{"tool_name": "orrery_state", "tool_args": {}}` answers the state
  view. `call_tool` maps underscores to hyphens for the file lookup, so either spelling of a name
  reaches the same tool.
- `GET /grubbery/mcp/api/src?tool=orrery_state` resolves the bare name to the desk's source file.

`tools/list` does not change, and is not the thing to watch. `+handle-request` in
`desk/gub/lib/mcp-rpc.hoon` filters that method to a three tool protocol allowlist (`echo`,
`list_tools`, `call_tool`) whatever the registry holds, by design: `nex/mcp.hoon` calls it "the
three-tool protocol allowlist that tools/list advertises to MCP clients". Clients reach everything
else through `list_tools` and `call_tool`.

Every desk under the shell that ships a `code/lib/tools` directory joins the registry, not just
orrery. On `~wex` that means `wallet.desk` and its fourteen tools arrived alongside orrery's
eight. Worth a line in the release notes.

The threat model changes, and it is worth stating plainly. The patch does not widen reachability: any file in any code namespace was already runnable by absolute path through `call_tool`, so no tool becomes callable that was not callable before. It widens advertisement: every installed desk's `code/lib/tools` directory is now listed to the user's MCP client, so a desk that ships tools is announcing them to whoever holds that client. Those tools run under the mcp tools child's weir, not under the desk's own ask, so what a desk tool can reach is what the mcp nexus was granted. And a bare-name collision across desks resolves in map order, so a desk's tools should carry a prefix the way orrery's do.

`+await-tool` in `nex/mcp.hoon` has no callers: `tools/call` delegates the run to the `tools.tools`
child, and `desk/gub/nex/tools.hoon` resolves only its own seeded `/code` and the root
`/code/lib/tools`, deliberately. The patch improves its loop for consistency; nothing runs it.

## How it was rehearsed

On `~wex`, 2026-09-17, in two passes, each saving the original and comparing it byte for byte
against the upstream file first, so the rehearsal patched what the ship actually runs.

| file | where it lives in the ball |
|---|---|
| `nex/mcp.hoon` | `/grubbery/ball/code/nex/mcp.hoon`, instance `/grubbery/ball/apps/mcp.mcp` |
| `call-tool.hoon` | `/grubbery/ball/apps/mcp.mcp/tools.tools/code/lib/tools/call-tool.hoon` |
| `list-tools.hoon` | `/grubbery/ball/apps/mcp.mcp/tools.tools/code/lib/tools/list-tools.hoon` |

```bash
W=http://localhost:8080; CK=/tmp/wex.cookies
F=$W/grubbery/ball/code/nex/mcp.hoon                                  # or a tools.tools file
curl -s -b $CK "$F?raw=1" > orig.hoon                                 # keep this
curl -s -b $CK -X POST --data-urlencode action=write-text \
  --data-urlencode content@patched.hoon "$F"                          # answers: saved
curl -s -b $CK -X POST --data-urlencode action=reload-nexus "$W/grubbery/ball/apps/mcp.mcp"
sleep 20
curl -s -b $CK "$W/grubbery/ball/apps/mcp.mcp?info=1"                 # bang: null
```

To revert, write the originals back the same way and reload again. The `orig.hoon` copies are one source of them. The other is the grubbery checkout at `/home/sneagan/software/groundwire/grubbery`, whose `desk/gub/nex/mcp.hoon`, `desk/gub/lib/tool-bundle/tools/call-tool.hoon` and `desk/gub/lib/tool-bundle/tools/list-tools.hoon` are the unpatched originals until `git apply` lands the patch there.

The nexus needs the reload. The two bundle tools do not: the tools nexus compiles a tool on each
call, so `call_tool` answered the new way the moment the file was saved. Both instances read
`bang: null` afterward.

What the rehearsal measured, with the patch in place:

```
call_tool {"tool_name": "orrery_state"}   ['actions','at','bodies','me','rev','schema','situations']
list_tools {"names_only": true}           37 tools:  (15 root, 8 orrery, 14 wallet)
echo {"message": "hi"}                    hi
tools/list                                3  ['call_tool', 'echo', 'list_tools']
api/tools-tree                            root 15 + apps/orrery.desk 8 + apps/wallet.desk 14
```

`list_tools` prints each tool's own declared `++  name`. For orrery's tools that is the underscore form, `orrery_state`, which is also the name the tools tree derives from the file name `orrery-state.hoon`. So the two listings agree, and `call_tool` reaches the same tool under either spelling, because it maps underscores to hyphens before it looks for the file.

The rehearsal was left in place on `~wex`: no bang, the kernel's own tools all still answer, and
the registry is a strict superset of the old one. Both gates
(`scripts/mcp-matrix.py`, `scripts/api-matrix.py`) pass with it.

Calendar's and auspex's tools can leave the kernel's own bundle once this lands.
