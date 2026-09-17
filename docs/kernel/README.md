# Kernel patch: MCP discovery walks the shell's desks

The mcp nexus discovers app tools by scanning `/apps/<app>/desk/code/lib/tools`, which predates
desks living under the shell at `/apps/shell.shell/desks/<name>.desk/desk/code`. Orrery's tools
are callable by absolute path without this patch; with it they are discovered by name as well,
advertised under `apps/orrery.desk`.

`mcp-desk-tools.patch` applies to `desk/gub/nex/mcp.hoon` in the grubbery repo:
`git apply docs/kernel/mcp-desk-tools.patch` from the grubbery checkout, then release with the
dist branch.

## How it was rehearsed

On `~wex`, 2026-09-17. The kernel's nexus source is the ball file `/code/nex/mcp.hoon` and the
instance is `/apps/mcp.mcp` (neck `/mcp`, child `tools.tools`). The original was saved with
`?raw=1` and compared byte for byte against the upstream file first, so the rehearsal patched
what the ship runs.

```bash
W=http://localhost:8080; CK=/tmp/wex.cookies
curl -s -b $CK "$W/grubbery/ball/code/nex/mcp.hoon?raw=1" > mcp.hoon.orig   # keep this
curl -s -b $CK -X POST --data-urlencode action=write-text \
  --data-urlencode content@mcp.hoon.patched "$W/grubbery/ball/code/nex/mcp.hoon"
curl -s -b $CK -X POST --data-urlencode action=reload-nexus "$W/grubbery/ball/apps/mcp.mcp"
sleep 20
curl -s -b $CK "$W/grubbery/ball/apps/mcp.mcp?info=1"        # bang: None
curl -s -b $CK "$W/grubbery/mcp/api/tools-tree"              # apps/orrery.desk, eight tools
```

To revert, write `mcp.hoon.orig` back the same way and reload again.

`bang` came back `None`. The registry the nexus builds gained two directories it had never seen:
`apps/orrery.desk` with the eight orrery tools (`orrery_act`, `orrery_actions`, `orrery_body`,
`orrery_observe`, `orrery_resolve`, `orrery_retract`, `orrery_schema`, `orrery_state`) and
`apps/wallet.desk` with wallet's fourteen. `GET /grubbery/mcp/api/src?tool=orrery_state` resolves
the bare name to `/apps/shell.shell/desks/orrery.desk/desk/code/lib/tools/orrery-state.hoon`. The
rehearsal was left in place: the patched registry is a superset of the old one, and the root
registry of fifteen kernel tools is untouched.

One deviation from the drafted hunk: `+weld` casts its result to the type of its second argument,
so welding the `(list path)` of app paths onto the raw product of the desks `+turn` is a
`nest-fail`. The patch adds a `^-  (list path)` over that `+turn`.

## What the patch does not reach

`tools/list` does not change, and was never the thing to watch. `+handle-request` in
`desk/gub/lib/mcp-rpc.hoon` filters it to a three tool protocol allowlist (`echo`, `list_tools`,
`call_tool`) whatever the registry holds, so its count is three before and three after. The full
registry is served at `/grubbery/mcp/api/tools-tree` and reached by clients through `list_tools`
and `call_tool`.

Calling a desk tool by its bare name still fails. `+get-app-mcp-paths` is one of three places in
the kernel that walk `/apps` with the old layout, and it is the only one this patch touches:

| where | what it feeds | patched here |
|---|---|---|
| `desk/gub/nex/mcp.hoon`, `+get-app-mcp-paths` | `+gather-tools-tree` (`/api/tools-tree`) and `+find-tool-src` (`/api/src`) | yes |
| `desk/gub/lib/tool-bundle/tools/call-tool.hoon`, its `Try app namespaces` loop | the `call_tool` meta tool, which is how an MCP client runs a tool by name | no |
| `desk/gub/lib/tool-bundle/tools/list-tools.hoon`, its `App namespace tools` loop | the `list_tools` meta tool's listing | no |

Each bundle tool carries its own copy of the `(welp ~[%apps i.app-kids] /desk/code/lib/tools)`
scan and needs the same second pass over `/apps/shell.shell/desks` before `call_tool` and
`list_tools` see a desk's tools. `+await-tool` in `nex/mcp.hoon` has no callers left:
`tools/call` delegates the run to the `tools.tools` child, and `desk/gub/nex/tools.hoon`
resolves only its own seeded `/code` and the root `/code/lib/tools`, by design.

Until those two land, orrery's tools are called by absolute path, which is what
`scripts/mcp-matrix.py` exercises. Calendar's and auspex's tools can leave the kernel's own
bundle once all three land.
