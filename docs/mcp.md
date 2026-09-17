# The MCP tools

Orrery's eight tools give an analyst on the ship's MCP server the same views and writes as the HTTP API, as the owner. They live in `code/lib/tools` and run on the mcp nexus's tools child, reading the instance by absolute peek and writing through the one poke road to the writer.

## Calling them

- By path, today: `tools/call` with the name `/apps/shell.shell/desks/orrery.desk/desk/code/lib/tools/orrery-state` (and the file names `orrery-body`, `orrery-resolve`, `orrery-observe`, `orrery-retract`, `orrery-act`, `orrery-actions`, `orrery-schema`). The kernel's `call_tool` meta tool takes the same path as its `tool_name`.
- By name, once the kernel discovery patch in `docs/kernel` is released: `list_tools` and the tools tree advertise them under `apps/orrery.desk`, and `call_tool` takes `orrery_state` and its siblings. `tools/list` itself stays the kernel's three-tool protocol allowlist by design.
- `scripts/mcp-matrix.py` is the gate: the section 8 scenario through the tools, checked against the HTTP API.

## The tools

| tool | parameters | answers |
|---|---|---|
| `orrery_state` | `at`, `kind` | the state view: bodies with attributes and involvements, open situations, open actions, the beacon, the schema |
| `orrery_body` | `id`, `at` | one body: record, attributes, involved, open actions about it, the timeline |
| `orrery_resolve` | `q` | bodies whose name or alias matches, exact first |
| `orrery_observe` | `bodies`, `observations`, `by` | one result per item, with the observation id and whether it existed |
| `orrery_retract` | `id`, `note`, `by` | ok |
| `orrery_act` | `kind`, `title`, `payload`, `about`, `due`, `by` | the action id and its status, or the open twin |
| `orrery_actions` | `status`; or `id`, `status`, `note`, `by` | the list, or the transition |
| `orrery_schema` | `schema` | the schema, or ok after replacing it |

`by` defaults to `mcp`. A refusal is an MCP error with the same text the HTTP route would answer.

## What the analyst can see

Over MCP the analyst is the owner: every body, every attribute, sensitive ones included, and it can share and mint nothing (those stay HTTP, owner cookie). A client that should see less gets a scoped key (`docs/keys.md`) or a share (`docs/sharing.md`) instead.
