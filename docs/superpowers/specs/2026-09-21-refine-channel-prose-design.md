# Refine at approval, the channel rule, and the prose rules

Orrery version 36 does three things the owner asked for on 2026-09-21 after version 34 went live: a note typed under a proposed action refines it before approval; a message to a person who has a ship never goes over Telegram; and the text of every message follows the owner's prose rules. The client contract for the first is rule 17 of `orrery-utils/docs/writing-a-client.md`, written first and binding here.

## Refine at approval

`POST /api/actions/<id>/refine` with `{"text": "..."}`, for the owner's cookie or a key whose `actions` names the action's kind. The action must be `proposed`; any other status answers 409 with a note. One refinement runs at a time per action; a second while the first runs answers 409.

The route runs one model call through the generator's key, url and model (the reader's cheaper model is not used: a rewrite in the owner's voice deserves the generator's). The prompt carries: the refine instructions (the shared file `orrery-utils/common/refine-prompt.md`, held word for word in the lib as `refine-prompt` under `scripts/prompt-drift.py`); the schema's action kinds and payload shapes and its attribute notes, the way the reader carries them; the prose rules (below); the owner's clock (`local-iso` of now in the owner's timezone); the action as JSON; the bodies the text could mean: every person, place, org and thing by id with name and aliases, and every body the action is `about`, the way the reader's `bodies.ctx` lists them; and the owner's text. The answer is JSON: `{"action": {"title", "payload", "about", "due"}, "extras": [{"kind", "title", "payload", "about", "due"}], "refused": ""}`.

The ship checks the answer before anything is filed, with the reader's own rules where they apply: the revised action keeps its kind; its payload has every `required` key of the schema's shape and no key outside it; a `one of` key holds a listed value; `to` and every `about` name a body the ship has (a name the model wrote is resolved against the pool the way the reader's `ground` does; one it cannot resolve refuses the whole refinement with `no person named <x> on the ship`); a time parses as ISO 8601 (a bare local time is read on the owner's clock); an extra passes `validate-reader`'s checks as a proposal would, and an extra of kind `calendar` stands against the original's times the way rule 14 holds a calendar action to its message (start ahead of now and within the year, an end after the start). `refused` non-empty, or any check failing, files nothing and answers `{"ok": false, "note": ...}`.

Filing is two writer ops. `revise-action {id, title, payload, about, due, by}` rewrites those four fields of a `proposed` action in place, keeps its id and history, and appends one step `[now %revised by]`; the transition table is untouched, since the status does not move; `by` is the key's name or `user`. Then one `act` per extra, `by` the same, its payload carrying `refined_from: <original id>` and its `about` including the original's `about`; auto-approval applies to extras as to any act (a `task` under `auto` lands approved). A twin refused by the writer drops that extra with a note in the answer. The route answers `{"ok": true, "action": <the revised action's view>, "extras": [<each filed extra's view>], "note": <dropped extras, if any>}`. The beacon moves on the revise, so the page and every client redraw.

On the page, a proposed action in the actions view gets one input under it with a placeholder `a note for this action` and a button; the answer redraws the row and adds the extras; a refusal shows its note under the input. The trail records `revise-action` like any op.

## The channel rule

At `act`, a `message` whose `via` is `telegram` or `mail` and whose `to` is a person with a `ship` attribute is filed with `via` `chat` and the trail notes `via rewritten to chat: <to> has a ship`. Telegram is for a person with no ship; `mail` (auspex) stays for a person with a ship only when the proposer asked for mail and the person has no chat, which today never happens, so `mail` is also rewritten to `chat`. The schema's note for `via` becomes `required: one of chat, telegram, mail; chat when the person has a ship, telegram only when they have none`. `plan-exec` is unchanged: `chat` is Talon's, and a rewritten message waits for Talon's pass.

The starter schema is a fall; ricsul's stored `schema.json` is its own document. At release the controller merges the two changed notes (`via`, `text`) into ricsul's stored schema through `PUT /api/schema`, so the models on the live ship read the new notes at once.

## The prose rules

The owner's rules, verbatim in the schema's note for `message.text` and in the shared prompts (`analyst-prompt.md`, `generator-prompt.md`, `refine-prompt.md`), which the lib's cords mirror under the drift check: no em dashes; no semicolons or colons joining independent clauses; simple direct sentences of varied length; a sentence with more than one parenthetical thought is split in two. As the last line, the executor replaces an em dash (U+2014) in outgoing text with a comma, with one space after it and none before, ahead of `sendMessage` or the auspex poke, so none leaves the ship whatever a model wrote.

## Out of scope

Refining an approved or claimed action (approve first, and a done one is history). A refinement that changes the kind (the model may propose the other kind as an extra instead). Reading Tlon chats on the ship (deferred by the owner). A `chat` executor on the ship.
