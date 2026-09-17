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

`by` defaults to `mcp`. In an observe batch it is per item: an observation's own `by` wins over the batch's, and either is refused over 64 bytes.

A refusal is an MCP error carrying the text the HTTP route would answer, with three deltas. `orrery_body` says `id: expected <kind>/<slug>` where the route says `expected <kind>/<slug>`; `orrery_actions` with no status to move says `status: required to move an action`; `orrery_observe` refuses a non-array `bodies` or `observations` where the route reads an absent one as empty. Everything else refuses with the route's text.

One refusal has no route counterpart. `orrery: peek refused` means the mcp tools child was not granted a peek into the instance, so a missing body could not be told from a vetoed read. On `~wex` the mcp instance holds the whole ball and it never appears.

## What stays on HTTP

Some routes have no tool and stay the owner's over the cookie: `DELETE /body/<kind>/<slug>`, `POST /bodies`, `GET` and `PUT /policy`, and the sharing and client key routes (`docs/sharing.md`, `docs/keys.md`).

The writer's trail is not a tool either. `/tr/last`, the last writer outcome, is read through the ball browser at `GET /grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/tr/last?raw=1`, and `/tr/log` beside it holds the last 500 ops.

## What the analyst can see

Over MCP the analyst is the owner: every body, every attribute, sensitive ones included, and it can share and mint nothing (those stay HTTP, owner cookie). A client that should see less gets a scoped key (`docs/keys.md`) or a share (`docs/sharing.md`) instead.
