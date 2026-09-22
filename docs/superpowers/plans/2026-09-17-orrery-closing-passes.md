# Orrery closing passes: bugs, privacy, polish

After phase 4 closed, three whole-repository review passes ran on 2026-09-17, each with one lens, one consolidated fix round and one scoped re-review: bugs, privacy and polish. Passes 1 and 2 landed together in commit dd43228. Pass 3 landed in commit d5e7aa4, which also bumped `code/version.json` to 7.

## Pass 1: bugs

Reviewer: fable, whole repo at commit 87a0981. No Critical findings, 5 Important, 12 Minor.

**Fixed**
- P1-I1: compaction aged a row by its `at` alone, so a fact recorded about something long past was culled the moment it was superseded. Fixed: `+compact` now keeps a row until the later of `at` and `seen` crosses the horizon, and the spec and `docs/sharing.md` retention text say so.
- P1-I2: a carried batch onto a body no longer present locally still reported success. Fixed: `+mirror-pass` checks the target body exists before carrying and answers that the shared body no longer exists; `+take-edit` notes the same case through the inbox.
- P1-I3: `+remote-poke-wait`'s comment called a timeout not a failure, but the arm answered `%.n` on one anyway. Fixed: a timer wake now answers `%.y`, a veto or nack still answers `%.n`, and `docs/sharing.md` explains what that means for `notified` and for a pushed batch.
- P1-I4: accepting a narrowing offer left an earlier, wider offer still pending and acceptable later. Fixed: `+take-offer`'s in-place branch now deletes the key from `share-offers.json` when it writes the narrowed mode.
- P1-I5: `DELETE /body` removed the body but left its share record and peek grant standing. Fixed: `+serve-delete-body` now calls a new `+drop-share` that removes the share record and rewrites the group to no ships; the two-ship gate gained a check for it.
- P1-M6: a batch listing the same body or observation twice answered inconsistently for the repeat. Fixed: `+body-results` and `+obs-results` track a seen set of ids and answer `existing: true` for repeats.
- P1-M8: `+de-iso` accepted invalid calendar dates, such as day 30 of February, and rolled them over. Fixed: it re-encodes the parsed date and refuses on a mismatch with the input; unit cases cover a rejected and an accepted date.
- P1-M9: `+write-body` and `+write-obs` reported `changed` even when the underlying soft make was vetoed. Fixed: both bind the soft make's answer and count a change only when it succeeded.
- P1-M10: `+serve-observe` accepted a non-array `bodies` field instead of refusing it. Fixed: it refuses a non-array `bodies` with 400, while an absent key still reads as empty.
- P1-M11: `orrery_act` could run against `person/me` before it existed on a fresh instance. Fixed: it now runs `ensure-me:om` first, the way the observe tool does.
- P1-M12: `serve-accept` upserted `person/me` on accept, so a fresh install's own self could be renamed to the host's name. Fixed: it now treats `person/me` as existing, the way `+first-missing` does.
- P1-M14: the page's re-render could wipe text being typed into a focused textarea. Fixed: `bumped()` now returns early while a `TEXTAREA` inside `#view` has focus, and refreshes on the next bump after blur.

**Left**
- P1-M7: a pinned `proposed` twin of a closed action still answers the closed action's id while the writer refuses it. Left: deferred to the polish list.
- P1-M13: `self-base` picks an arbitrary lane when two instances claim the same name. Left: deferred to the polish list.
- P1-M15: the page's keep path is fixed and does not adapt to other installs. Left: deferred to the polish list; already documented behavior.
- P1-M16: the phase 1 gate's day-keyed situation can orphan, the MCP gate compares two instants loosely, and a push check can pass on a refused push. Left: deferred to the polish list.
- P1-M17: `status-of` labels a null multi row as superseded. Left: deferred to the polish list.

## Pass 2: privacy

Reviewer: fable, whole repo at commit 87a0981, run in parallel with pass 1. No Critical findings, 4 Important, 7 Minor.

**Fixed**
- P2-I1: a writing key could retract, and thereby confirm, a row it could only see veiled, because `+serve-retract`'s visibility check never looked at the value's ref target. Fixed: a row whose value resolves to a kind outside the key's scope is now invisible too and answers the same 404; the key gate gained checks for it.
- P2-I2: `policy.sensitive` was not applied to sharing in either direction, and the docs did not say so. Fixed: pushing now skips rows whose attribute is sensitive, `docs/sharing.md` states a read grant carries the body whole and only the push direction is filtered, and the spec's section 11 sentence was corrected; the two-ship gate gained a sensitive-attribute check.
- P2-I3: `docs/sharing.md`'s claims that the pointer itself never travels and sharing is one hop described orrery's own copy, not what the peer reads off the wire. Fixed: both sentences were reworded to say the peer reads the host's whole directory, and orrery itself stores only the host's own rows locally with the source pointer replaced.
- P2-I4: `docs/mcp.md` claimed the MCP surface can share and mint nothing, which is true of the tools but not of an analyst reaching the mcp server's weir. Fixed: reworded to say an analyst can do anything the owner can, including through the writer, and that scoping one needs a key or a share on another ship.
- P2-M5: carried operations from a shared peer wrote a note into `/tr/log` for every carried retraction or batch. Fixed: carried ops are marked `via: ship` and noted through the inbox ring instead.
- P2-M6: peer-supplied text in the audit rings had no length cap. Fixed: `+note-refusals` and `sync-one`'s `refused` map now truncate the oid to 64 bytes.
- P2-M7: a local client could forge a `ship` source on an observation. Fixed: `serve-observe` and `orrery-observe` now refuse any item whose `source.kind` is `ship`, since only the inbox may set it; the key and MCP gates gained checks.
- P2-M8: `docs/keys.md` did not say what a veiled row actually reveals. Fixed: it now states a veiled row reveals only that some body of a kind outside the key's kinds is referenced, at that time, by that source, and nothing else.
- P2-M9: `+group-name` joined kind and slug with a hyphen, so two different kind and slug pairs could collide and one share would silently replace another's grant. Fixed: the separator is now a dot, `orrery-<kind>.<slug>`, with the unit test, the two-ship gate and `docs/sharing.md` updated to match.
- P2-M10: `orrery-schema`'s refusal text did not match the HTTP route's wording, and `docs/mcp.md` undercounted the MCP tool deltas while overstating what `call_tool` can reach. Fixed: the refusal text now matches, the docs add the 64-byte `by` cap as a fourth deliberate delta, and the absolute-path claim was removed.
- P2-M11: `+handle-request` accepted a POST or PUT body with no content-type check. Fixed: it refuses with 415 unless the content type starts `application/json`.

**Left**
- None: every pass 2 finding was ruled FIX, so nothing was deferred to the polish list.

## Pass 3: polish

Reviewer: opus, whole repo at commit dd43228. No Critical or Important findings; 24 new items, N1 to N24, plus the carried polish list's 25 items, each ruled TAKE or LEAVE.

**Fixed**
- the carried suffix item: `+handle-request` declared its trailing-slash-trimmed `suffix` binding twice. Fixed: the first binding is now `suffix0`, and the trim reads from it.
- the carried divider-style item: 13 lines in `tests/lib/orrery.hoon` carried a bare `::` above a `::  ==` divider as well as below, against grubbery's style guide. Fixed: the 13 extra lines above the dividers were deleted.
- the carried mixed-batch item: the key gate's mixed-batch check passed even on a failed owner read, since it only asserted the value was not the batch's bad string. Fixed: `key-matrix.py` now pins the actual value the setup wrote.
- the carried veiled-counter item: the key gate's veiled-row test used only one veiled row, so the synthetic counter was never pinned across two. Fixed: a second veiled row was added and the index assertions were pinned.
- the carried drop-names item: `drop-names` on a multi-valued attribute was untested. Fixed: `likes` was added to the hide set, with assertions that it drops from both `multi` and the person attributes.
- the carried until-round-trip item: the test compared `~` with `~` because its observation had no `until` to round-trip. Fixed: the test now sets a real `until` and pins it on both sides.
- the carried receive-obs item: a non-object payload to `receive-obs` was untested. Fixed: one `expect-eq` confirms it passes through untouched.
- the carried `orrery_act` item: the tool accepted a `proposed` argument without declaring it in its parameters. Fixed: `orrery-act.hoon`'s `parameters` now names `proposed`, matching the handler and both tool tables.
- the carried kernel-README item: `docs/kernel/README.md` mixed hard-wrapped paragraphs with three unwrapped ones, against the plans' rule. Fixed: the whole file is unwrapped, with headings, tables and code blocks kept byte for byte.
- the carried nosniff item: the page served files with no `x-content-type-options` header. Fixed: `serve-file` now adds `nosniff` to its response headers.
- the carried accessibility item: the settings textareas and the body-view table headers carried no accessibility markup. Fixed: both textareas gained `aria-label`, and every `<th>` in the body tables gained `scope="col"`.
- the carried 415 item: a bodiless POST with a non-JSON content type still answered 200. Fixed: one added conjunct in `app.hoon` checks the body's length is nonzero, since eyre hands a bodiless POST a present but zero-length body.
- the carried group-check item: the ship-share gate's own descriptions claimed to prove a specific ship joined or left a group. Fixed: the three descriptions in `ship-share-matrix.py` were reworded to say only that the group is non-empty or empty.
- N1: the file-top tree comment in `app.hoon` was two phases stale, missing the paths phases 2 and 3 added. Fixed: the missing rows were added to the map.
- N2: `key-matrix.py`'s cleanup mutated the owner's schema in place before storing it as the restore baseline, so a schema that legitimately named `health` would lose it. Fixed: the baseline is now a deep copy taken before the mutation.
- N3: an aborted `ship-share-matrix.py` run could leave `sensitive: ['health']` on the second ship as a permanent policy, since the next run captured it as its own baseline. Fixed: the baseline capture now strips that exact marker before storing it.
- N4: `api-matrix.py`'s day-keyed situation id could leave a stale open situation across a midnight UTC boundary. Fixed: section 0 now deletes every body whose id starts `situation/` and ends `-breakdown` before the fixed deletions.
- N5: the three read tools, `orrery-state`, `orrery-body` and `orrery-resolve`, ignored a vetoed `ensure-me:om` peek and answered as if the body were simply missing, contradicting `docs/mcp.md`'s promise. Fixed: all three now check the peek's answer and refuse, matching `orrery-act` and `orrery-observe`.
- N6: the audit log never named the actor on a local observe, since `app.hoon` computed `who` and then passed an empty string to the note. Fixed: the local branch now passes `who` to `note-by`.
- N7: `page-smoke.py` silently dropped two stream checks whenever its KEEP regex failed to match, while still printing ALL OK at a lower count. Fixed: both checks now run unconditionally, so a miss fails loudly and the count is fixed at 13.
- N8: the page's three purest pieces, `seg`, the route parser and the SSE line parser, sat below the `document` guard in `orrery.js`, so node could never test them. Fixed: `seg` was lifted unchanged, `route()` now takes an explicit hash argument, the SSE parser became `sseEvent(block)`, and all three are exported and covered by new `page-test.js` assertions.
- N9: `code-closure.py` carried an inherited em-dash. Fixed: replaced with plain punctuation.
- N10: `/tr/inbox` was named three times in `docs/sharing.md` but the doc never said where to read it. Fixed: the doc now gives its ball-browser path, matching how `docs/mcp.md` already documents `/tr/last` and `/tr/log`.
- N11: `docs/sharing.md` explained what `notified` means in a bullet that does not define it. Fixed: the sentence moved to the bullet where `notified` is defined, and "the first hop" was reworded to "the first offer".
- N12: `docs/mcp.md`'s opening line claimed the MCP surface matches the HTTP API's views and writes, contradicting its own "What stays on HTTP" list further down. Fixed: the opening line now carves out an exception for those routes.
- N13: three sentences in the spec no longer matched the repo, naming a doc that does not exist, a stale phase-3 path list, and a gate script by the wrong name. Fixed: three one-line corrections.
- N14: `serve-body` loaded and scoped every action before it could even 404 on a missing body. Fixed: the 404 check now runs first, matching the idiom already used elsewhere in the file; the same reorder was applied to `orrery-body.hoon`'s tool twin.
- N15: `apply-carried` reported an uncapped poke count, wider than the capped list it actually applied. Fixed: the capped list is bound once and used for both the pokes and the reported count.
- N16: the five-pair trail entry was built twice, once in each note arm. Fixed: factored into one pure `+trail-entry` arm called by both.
- N17: sixteen arms, though the finding's own headline undercounted it as twelve, had no headline comment while their siblings did. Fixed: all sixteen gained a `::  +arm: headline` line.
- N19: `serve-resolve` passes an empty hide set where every other call site passes a computed one, reading as an omission even though it is correct. Fixed: one comment line explains why.
- N20: `do-set-action` named a leg `by`, shadowing the map door against the phase 4 naming rule its sibling `do-*` arms follow. Fixed: renamed to `who`; the nine unrelated `by=@t` gate samples were left alone since none of those arms uses a `by` door.
- N21: `docs/releasing.md`'s release checklist did not say that step order matters, since deleting bodies also revokes the share the sharing gate depends on. Fixed: step 5 gained a clause saying it must run first.
- N22: `self-base` takes an arbitrary lane when two instances claim the same name, with nothing explaining why. Fixed: one comment line names the limitation; the code itself was left, since a desk app cannot learn its own path any better.
- N24: the `%future` fold status was unreachable in the test suite. Fixed: `test-status-and-timeline` gained a row dated one day ahead, asserting `%future` and pinning that a future row never wins the fold.

**Left**
- the carried take-edit item: the trail row logs `ok: true` when some rows in a batch were refused. Left: the spec defines the trail row as whether it applied, and the rows did apply; the count and first reason already sit in the same entry.
- the carried refused-map item: the refused map on an accepted row evicts by map order past 200 entries. Left: an evicted entry is simply re-noted on the next pass, which is bounded and harmless.
- the carried ship-remotes item: `ship-remotes.json` has three read-modify-write writers, so a revoke inside a request fiber's window can be lost. Left: structural, it needs a writer op and a new poke shape.
- the carried follower-prod item: a late ack or a stale wake counts as a follower prod. Left: harmless by construction.
- the carried batch-seen item: batch observations share one seen value, so ties resolve by map order. Left: structural, the ship stamps one now per batch.
- the carried no-op-cull item: a no-op resubmit can cull rows without a beacon bump. Left: compaction on an unchanged write is the design.
- the carried tr-log item: `/tr/log` is rewritten once per note. Left: structural, the ring is one grub.
- the carried long-lines item: Hoon lines over 80 columns, some deliberately aligned tables and prose strings among them. Left: a mechanical rewrap of the two most-exercised files is the one change in the report whose risk outweighs its value.
- the carried vendored-dash item: an em-dash inside the vendored `poke-ack` marc. Left: verified all twelve vendored marcs are still byte-identical to grubbery's own, and that cheap identity check is worth more than one dash.
- the carried icon.svg item: `code/icon.svg` is duplicated under `nex`. Left: verified lattice, auspex and calendar all ship both copies, so this is the shared convention.
- the carried scope-schema item: `scope-schema` passes schema fields other than kinds, multi and actions through unfiltered. Left: no such field exists today, and filtering unknown fields would hide the owner's own additions from a key.
- the carried per-body-counter item: the veiled counter restarts per body, so ids in a key's view are unique only per body. Left: only the body view emits rows, and it emits one body; `docs/keys.md` already claims no more than that.
- the carried ship-refusal item: a key sending ship "" is refused while null passes, and a key cannot re-upsert a body carrying a ship. Left: `docs/keys.md` states the rule, and the refusal names `ship` accurately.
- the carried actor-on-refusal item: a refused or no-op retract note names no actor. Left: `refuse` and `note-then-no` have sixteen callers between them, and most refuse before any actor is decoded, so the cost is above the value.
- the carried uncapped-by item: the owner's HTTP `by` on retract and set-action is uncapped. Left: `docs/mcp.md` names this as one of four deliberate tool deltas, so a doc relies on it.
- the carried fix-check-rows item: two retracted fix-check rows sit on the dev ship's `person/me`. Left: ship residue, nothing in the repository to change.
- the carried CSP item: the page has no Content-Security-Policy header. Left: one wrong header cannot break rendering, but a wrong CSP breaks the page silently and no gate can see it.
- the carried call_tool item: the cost of a `call_tool` miss. Left: kernel behavior, already written up in `docs/kernel/README.md`.
- the carried kernel-patch item: the nexus-versus-bundle early return and naming drifts in the kernel patch. Left: the patch is rehearsed byte for byte on the dev ship and `git apply --check` passes against it today; editing it would invalidate that rehearsal.
- the carried terminal-actions item: terminal gate actions accumulate with no way to delete one. Left: there is no route to delete an action, and adding one is a behavior change, not polish.
- the carried closure-regex item: the positional regex in `code-closure.py`. Left: it works, is green today, and already carries eleven lines explaining why it is shaped that way.
- the carried known-set item: `orrery-observe`'s known set is built from `bodies.prep` rather than the per-item answers. Left: unreachable after `ensure-me`, as the code's own note says.
- the carried retention-0 item: retention 0 can leave a same-batch superseded row alive for one extra pass. Left: same root cause as the batch-seen item above.
- the carried group-check-scope item: the ship-share gate's group check proves the group is non-empty or empty, not which ship is in it. Left: naming the ship would need an unverified `who.ships?raw=1` read, and a polish round should not gamble a gate.
- the carried oid-collision item: truncated oids could collide in the refused map. Left: orrery's own oids are 19 bytes, so the 64-byte truncation never actually fires; the cap exists to bound a hostile peer's text and does.
- N18: the read-json-then-object idiom repeats at 21 sites in `app.hoon`. The reviewer ruled TAKE, adding `+read-fields` and `+gm`, but the controller left it: a 21-site mechanical rewrite at the closing round, for about eighteen lines saved, risks a slip in a branch only the two-ship gate reaches.
- N23: the README's route list omitted `actions/<id>` and gave no install instructions, ruled TAKE, but dropped mid-round on the controller's instruction because `README.md` was being rewritten separately; the later implementer report, not the rulings doc, is the source for this outcome.

## Deviations

- `+note-inbox` at depth 1: the P1-I5 ruling said to note through `note-inbox` when `self-base` answers null, but `note-inbox`'s road is fixed at the nexus root while `+serve-delete-body` runs one step down on a request fiber, so `note-inbox` became a one-line wrapper over a new `+note-inbox-at`, called with `up` 1, leaving every existing call site unchanged.
- `+ship-source` and `+mark-reserved` live in the library: the P2-M7 ruling put the refusal in the two callers, and it does live there, but the two predicates those callers share are now library arms so the nexus and the tool cannot drift apart; no unit case was added, as the ruling directed.
- the two-ship gate's group check reads a size, not the ships: the P1-I5 ruling wanted a check that the group no longer lists the second ship, but the `?info=1` read of a `who.ships` grub cannot be spelled that way, so the gate instead asserts the group's size is non-empty while the share is live and empty after the revoke, without naming the ship.
- the delete-body gate section re-creates and re-shares the body: the ruling allowed either order, and the gate runs the delete after the re-share section so the run ends with a live share record, which is what lets the next run's `clean()` revoke it; verified rerunnable across three consecutive green runs.
- the 415 conjunct's exact shape: the item-23 finding expected one added conjunct checking that a body was present, but `app.hoon` already had that check; the real gap was that eyre hands a bodiless POST a present, zero-length body, so the added conjunct instead checks the body's length is nonzero.
- the mixed-batch check's reading of "positive": rather than only requiring a 200 status, the fix pins the exact value the gate's setup wrote, which also rules out a read that returns 200 with stale or wrong data.
- N17's count: the finding's own headline said twelve arms lacked a headline comment, but it went on to list sixteen; all sixteen listed arms were given one.
- N8's table markup: the two `<table>` header strings in `body()` were split across two source lines rather than kept on one very long line, because `scope="col"` on six or seven cells made a single line unreadable; the emitted HTML itself is unchanged.

## Residues on the dev ships

- old `orrery-person-sarah.grp` groups on both the dev ship and the second ship still hold whatever ships were granted before the P2-M9 separator rename; nothing in the current build writes to those groups any more, so the stale grants stand until each ship is reset, and the release ship has none yet.
- two retracted fix-check rows sit on the dev ship's `person/me`, left over from an earlier round, with nothing in the repository to change.
- the kernel patch's early-return and naming drifts were left because the patch is rehearsed byte for byte against the dev ship's checkout and `git apply --check` passes against it today; editing the patch file in the repo would invalidate that rehearsal.

- the dev ship's kernel ball carries the three patched discovery files from the rehearsal of `docs/kernel/mcp-desk-tools.patch`; the second ship's does not. The patch reaches production only through grubbery's dist branch.

## Gates at the close

| Gate | Result at d5e7aa4 |
|---|---|
| unit arms (the dev ship's rev 239) | 51 OK, 0 failed, 0 crashed |
| `api-matrix` | ALL OK, run twice |
| `key-matrix` | ALL OK, 88 checks |
| `mcp-matrix` | ALL OK, 35 checks |
| `page-test` | ALL OK, 24 checks |
| `page-smoke` | ALL OK, 13 checks |
| `ship-share-matrix` | ALL OK, 79 checks |
| `code-closure` | closed, 35 files |
| `tools.hoon` cmp | identical, no diff |

## Structural items left on the record

- The ball walkers in `app.hoon` and `orrery-mcp.hoon`, with `find-loaded`, `open-twin`, `body-results` and `obs-results`, stay duplicated: the nexus uses nexus-relative roads and the tools absolute ones, the tool results carry a peek answer the nexus has no use for, and the phase 4 import rule leaves no third file to hold a shared walker.
- The double fold of situations in `state-json` and `body-json` stays: removing it means restructuring the one arm three surfaces and four gates read, for no behaviour change.
- The `apply` dispatch chain, the aligned route table and the spelled-out fiber casts inside `;<` continuations stay as they are: consistent with themselves, and the plans warn about `;<` continuations.

## After the passes

- The scoped re-review of the polish round (opus) found every item addressed and no new Critical or Important breakage. Two notes stay on record: the two-ship gate's peer baseline drops a `sensitive` list equal to the gate's own marker, so a peer that legitimately named only `health` would lose it after a run; and `api-matrix.py`'s deletion of stale breakdown situations is unchecked by design.
- Version 7 went to the dev ship through the forge pull and the second ship followed by version; every gate ran green on the synced code on both ships, with `bang` null on each.
- The README was rewritten at the user's request as a walk from what orrery is for to the reference, in commits b4596c6, b2d08ae and a1606ae; the re-review checked its claims against the code and its ten corrections are in.
