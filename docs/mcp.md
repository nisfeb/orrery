# The MCP tools

Orrery's nine tools give an analyst on the ship's MCP server the owner's views and writes over the HTTP API, apart from the routes under What stays on HTTP below. They live in `code/lib/tool-bundle/tools`. Since version 154 they run in orrery's own tools nexus, `/tools` under the instance, which the instance seeds on every load from `code/lib/tool-bundle`: the tools and copies of the three libs they import (`scripts/tool-bundle.py` keeps the copies equal). A tool reads the instance by a relative peek and writes through the one poke road to the writer.

## Calling them

- Through `call_tool`: `tools/call` with the name `call_tool` and the arguments `{"tool_name": "orrery_state", "tool_args": {...}, "path": "/apps/shell/desks/orrery.desk/desk/data/orrery.orrery_app/tools"}`. The other names are `orrery_body`, `orrery_resolve`, `orrery_observe`, `orrery_retract`, `orrery_act`, `orrery_actions`, `orrery_schema` and `orrery_preferences`; the file names (`orrery-state`) work too. The answer is the tool's own, errors included. A name orrery does not have answers an error naming the tool.
- The path is the instance's tools nexus. On an older kernel the shell is `/apps/shell.shell`, and the path follows it. The kernel's `call_tool` pokes `<path>/main.sig` and waits for the run it makes at `<path>/runs/<id>`, so the tool runs inside orrery, under orrery's weir.
- Before version 154, `path` was the desk (`.../orrery.desk/desk`), and the kernel compiled the tool from `<path>/code/lib/tools` and ran it itself. The current kernel relays instead, and a desk has no tools nexus, so that path no longer answers.
- The kernel's relay stops at the first change notice that finds the run done. A run that finishes in the event that made it leaves a second notice queued, and the request is never answered. So every tool first waits on a zero timer (`+settle` in `code/lib/orrery-mcp.hoon`). A name the tools nexus does not have fails in that same event, so that call still hangs until the client gives up; the kernel's own tools nexuses do the same.
- `scripts/mcp-matrix.py` is the gate: the section 8 scenario through the tools, checked against the HTTP API.

## The tools

| tool | parameters | answers |
|---|---|---|
| `orrery_state` | `at`, `kind`, `brief` | the state view: bodies with attributes and involvements, open situations, open actions, the beacon, the schema. With `brief` true, the view an assistant should read first: values without provenance, the open situations with what each needs, the open actions small, the kinds' attribute names; a tenth the size |
| `orrery_body` | `id`, `at` | one body: record, attributes, involved, open actions about it, the timeline |
| `orrery_resolve` | `q` | bodies whose name or alias matches, exact first |
| `orrery_observe` | `bodies`, `observations`, `by` | one result per item, with the observation id and whether it existed |
| `orrery_retract` | `id`, `note`, `by` | ok |
| `orrery_act` | `kind`, `title`, `payload`, `about`, `due`, `proposed`, `by` | the action id and its status, or the open twin |
| `orrery_actions` | `status`; or `id`, `status`, `note`, `by` | the list, or the transition, whose answer carries the `by` the ship stores for the step; a `claimed` move holds the action for ten minutes under the actor in `by`, `mcp` by default |
| `orrery_schema` | `schema` | the schema, or ok after replacing it |
| `orrery_preferences` | `style`, `preferences`, `by` | the style and preferences, or what they will be after changing either; the rest of the schema is left alone |

`by` defaults to `mcp`. In an observe batch it is per item: an observation's own `by` wins over the batch's, and either is refused over 64 bytes.

A refusal is an MCP error carrying the text the HTTP route would answer, with four deltas. `orrery_body` says `id: expected <kind>/<slug>` where the route says `expected <kind>/<slug>`; `orrery_actions` with no status to move says `status: required to move an action`; `orrery_observe` refuses a non-array `bodies` or `observations` where the route reads an absent one as empty; `orrery_retract` and `orrery_actions` refuse a `by` over 64 bytes, where the owner's own routes take any length. Everything else refuses with the route's text.

One refusal has no route counterpart. `orrery: peek refused` means the tools nexus could not peek into the instance, so a missing body could not be told from a vetoed read. The tools nexus sits inside the instance, so it should never appear.

## What stays on HTTP

Some routes have no tool and stay the owner's over the cookie: `DELETE /body/<kind>/<slug>`, `POST /merge`, `POST /bodies`, `GET` and `PUT /policy`, and the sharing and client key routes (`docs/sharing.md`, `docs/keys.md`).

`POST /instruct`, `POST /correct` and `GET /corrections` have no tool either. They are open to the owner and to a key with `write` (README, "Telling the ship"); `DELETE /corrections/<id>` is the owner's.

The writer's trail is not a tool either. `/tr/last`, the last writer outcome, is read through the ball browser at `GET /grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app/tr/last?raw=1`, and `/tr/log` beside it holds the last 500 ops.

## What the analyst can see

Over MCP the analyst is the owner: every body, every attribute, sensitive ones included. Orrery ships no tool for sharing or for minting a key, but that bounds the tools, not the analyst. What an MCP analyst can reach is the mcp server's weir, today the whole ball, so an analyst on this ship can do anything the owner can, the writer included. Scoping an analyst means a key or a share on another ship, which is what spec section 6 says.
