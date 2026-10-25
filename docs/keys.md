# Keys for clients that do not run a ship

A key is a token for one client: a name, the identity it writes as, and a scope. The owner mints it and sees the secret once. Requests carry it as `Authorization: Bearer <token>` with no cookie.

## Minting and revoking

- `POST /apps/orrery/api/clients` with `{"name": "The phone client", "by": "phone", "scope": {"kinds": ["person", "thing", "place", "situation"], "actions": [], "write": true}}` answers the row and the `token` once. Store it in the client; the ship keeps only a salted hash. The `by` may not be a name the ship signs its own writes with (`owner`, `user`, `http`, `calendar`, `ship`, `share`, `generator`, `reconcile`, `retire`, `browsing`, `telegram`, `chat`, `mail`, `web`) nor start with `~`, since the code reads those as the owner, the calendar, a share, a reader or a ship.
- `GET /apps/orrery/api/clients` lists the keys with their scope, when they were made and last used (to the hour), never the secret.
- `DELETE /apps/orrery/api/clients/<id>` revokes one. The next request with it is refused once the writer applies the drop, within a second.
- The page's Keys view (`/apps/orrery#keys`) is the same three calls with a form: the list with each key's scope, made and last used, a revoke button per key, and a mint form built from the schema's kinds and action kinds whose token is shown once until dismissed or the view is left.

## What a scope means

- `kinds`: the body kinds the key may see. The state, body and resolve views omit every other body, and a body outside them answers exactly what a missing body answers. With `write`, the key may observe those bodies and create them.
- The state view's `schema` is trimmed to those kinds, with the sensitive attribute names dropped from every `attrs` list and from `multi` unless the scope says `"sensitive": "write"`, and the `actions` list cut to the key's action kinds. `GET /schema` stays the owner's.
- `actions`: the action kinds the key may propose and list. With `write`, it may also approve, dismiss, claim and complete them. A claim holds an action under the key's identity: another client's claim is refused for ten minutes, and its done or failed is refused for as long as the claim stands, in both cases with `claimed by <identity>`.
- `write`: false makes the key read-only: it cannot observe, create bodies, retract or transition an action. Proposing needs only the action kind, so a read-only key with `actions` can still file a proposal for the owner to approve. A proposal of a kind the policy auto-approves is approved on the spot, and one it does not auto-approve waits for the owner.
- `sensitive`: `"none"`, the default, or `"write"`. With `"write"` the key may observe the attributes `policy.sensitive` names, on bodies within its kinds, and every view goes on hiding them from it. `"write"` needs `"write": true`; without it the mint is refused with `sensitive: write needs write`, and a missing or unknown value reads as `"none"`.
- `by` on everything a key writes is the key's identity, whatever the payload said, so the audit trail names the client.
- A key never sets a body's ship, neither as the `ship` field nor as a `~` alias (403 `not in scope: aliases`), and never files or retracts a `twin` row (403 `not in scope: twin`): identity, on this ship and across ships, is the owner's to assign. A `sphere` row from a key names a sphere of its kinds by ref; a sphere by name is 403 `not in scope: sphere`.
- Deleting a body and merging one into another (`POST /merge`) are the owner's, over the cookie: a key asking for either is 403 `owner only`.
- The address attributes `ship`, `telegram` and `email` (mail to a person with no ship goes to their email) are where the executor sends a person's approved messages, so a key writes them only with `"sensitive": "write"`, though it reads them. The same holds for `shared-with`, which shares a situation: a key writes it only with `"sensitive": "write"`, and even then the share waits for the owner's approval. A key may not propose a `merge` action (403 `a key may not propose a merge`), and the bodies an action's payload names (`to`, `from`, `into`) are held to its kinds as `about` is. A `fact`, `correct` or `resolve` action is carried out by the ship's own writer once approved, so it is held to the rows it would write: what `/observe` would refuse the key (an address or sensitive attribute, a subject or ref outside its kinds) is refused when the key files the action and when it approves one, and an approval that would name a body outside its kinds answers `no such action`. A `close` must name an action of the key's own kinds. `POST /instruct` from a key files only what `/act` would accept, and its `apply` is the owner's (403 `apply is the owner's`).
- Text a key hands to `POST /read` is read as the key: against the bodies and corrections the key can see, not every body on the ship, with the facts signed by its `by`, and whatever it could not have filed itself, a proposed action's payload included, dropped with a note.
- The chat reader's settings (`GET` and `PUT /chat`) take the owner or a key with `write`, since orrery 39, so the phone client can pick the DMs and channels the ship reads and hand over its own reading. Which ship is which person is identity, the owner's to assign: a key without the `person` kind reads the `people` map as empty, and a key's `PUT` naming `people` is 403 `not in scope: people`. The record, the wake and the two list routes stay the owner's. Every settings `PUT` (since 42) answers the document as stored once the write has landed, so a client reads its own write in the answer and need not read the route again to see it.
- Registering the Telegram webhook (`POST /telegram/webhook`) and reading what Telegram holds (`GET /telegram/webhook`) take the owner or a key with `write`, since orrery 38, so a client can finish a setup it walked the owner through. The settings themselves (`GET` and `PUT /telegram`) stay the owner's; the ship makes the Telegram call with the token it holds, and the key never sees it. A read-only key is 403 `read only key`.
- An action whose payload names an attribute hidden from the key (a `fact` or `correct` on `health`) is left out of every list and answers `no such action` by id, as a correction on one is left out.
- The browsing routes (`GET /browsing`, `/browsing/page` and `/browsing/recent`, `POST /browsing/file`, `/unrelate` and `/place`) answer a key from its own view: the bodies, plans and ties of its kinds, and the last pass without its notes, which name bodies of any kind. A body or plan outside its kinds answers as missing, and setting a plan's place needs the `place` kind too. A browser extension's key needs the kinds its panel is meant to show.
- `GET /world` gives a key the phone's current zone, as it gives the away line, only when its kinds include `situation`. Otherwise the zone is home's as the key's view holds it, else the generator's.
- A key may only relate what it can see. An observation whose value points at a body outside the key's kinds is refused, naming that body, so a key cannot confirm one by watching for an `existing` answer.
- A batch with one item outside the scope is refused whole, with the first offending id or attribute named. Nothing in it is written, including the items that were in scope.

## Sensitive attributes

`policy.json` starts with `"sensitive": ["health", "income"]`, the two attributes a triager puts medical and money facts under, and the owner may add to the list. A key never receives those attributes on any view and cannot retract them, whatever its scope, and it cannot observe them either unless its scope says `"sensitive": "write"`. The owner cookie sees everything. A ship seeded before version 11 keeps its own policy; add the line there by hand.

A writing key can learn that a name is sensitive by trying to observe it and reading the refusal. It never learns the value.

A key with `"sensitive": "write"` writes what it can never read: a messenger or a mail agent that hears "mom's biopsy came back clear" files the fact under `health` instead of under a name it invented. Its rows are stored as the owner's are, its state view's `schema` lists the sensitive attribute names so the client knows which attributes it may write, and the values stay the owner's. Retracting one of its own rows answers `no such observation`, since it cannot see the row.

## What to know

- The per-item answer for a row on an attribute the key may not read carries `ok` and `id` and no `existing`, so a key never learns whether the exact claim it sent was already held. The owner's answers keep `existing`.
- The state view's `rev` moves for a repeat of such a row exactly as it does for a fresh one, so watching `rev` tells a writing key nothing about what was there either.
- The owner cookie is never scoped. Keys are checked in the app, not by eyre, the way calendar checks CalDAV passwords.
- A key learns nothing about bodies outside its kinds: not their names, not that they exist, not through an action's `about` (trimmed to the key's kinds), not through an attribute whose value points at one (the key reads that attribute as cleared, never as an older value). Only a top-level `{"ref"}` value is veiled; a body id written inside free-form JSON is not.
- A veiled row carries a synthetic id of the form `veiled-<n>`, because the real id is a hash over the value it hides. Retracting that id answers `no such observation`, and so does retracting the real id, so a key that recomputes one learns nothing from the answer.
- What a veiled row does reveal is this much: that some body of a kind outside the key's kinds is referenced from that attribute, at that time, by that source. Not which body, not its name, not that it exists.
- The state view's `rev` moves on every write, in scope or out of it, so a key can tell that something changed without being told what.
- Action titles and payloads are free text and are not veiled. A title that names a body outside the key's kinds is shown as written.
- `by` and `source` on the rows a key reads name other clients and ships, since they are part of the audit trail.
- A key's `name` is 1 to 200 bytes and its `by` is 1 to 64.
- Last use is recorded at most once an hour per key.
- At most 50 keys; scope lists of at most 24 kinds each.
