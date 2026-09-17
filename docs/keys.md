# Keys for clients that do not run a ship

A key is a token for one client: a name, the identity it writes as, and a scope. The owner mints it and sees the secret once. Requests carry it as `Authorization: Bearer <token>` with no cookie.

## Minting and revoking

- `POST /apps/orrery/api/clients` with `{"name": "Talon on the phone", "by": "talon", "scope": {"kinds": ["person", "thing", "place", "situation"], "actions": [], "write": true}}` answers the row and the `token` once. Store it in the client; the ship keeps only a salted hash.
- `GET /apps/orrery/api/clients` lists the keys with their scope, when they were made and last used (to the hour), never the secret.
- `DELETE /apps/orrery/api/clients/<id>` revokes one. The next request with it is refused once the writer applies the drop, within a second.

## What a scope means

- `kinds`: the body kinds the key may see. The state, body and resolve views omit every other body, and a body outside them answers exactly what a missing body answers. With `write`, the key may observe those bodies and create them.
- The state view's `schema` is trimmed to those kinds, with the sensitive attribute names dropped from every `attrs` list and from `multi`, and the `actions` list cut to the key's action kinds. `GET /schema` stays the owner's.
- `actions`: the action kinds the key may propose and list. With `write`, it may also approve, dismiss, claim and complete them. A claim holds an action under the key's identity: another client's claim is refused for ten minutes, and its done or failed is refused for as long as the claim stands, in both cases with `claimed by <identity>`.
- `write`: false makes the key read-only: it cannot observe, create bodies, retract or transition an action. Proposing needs only the action kind, so a read-only key with `actions` can still file a proposal for the owner to approve. A proposal of a kind the policy auto-approves is approved on the spot, and one it does not auto-approve waits for the owner.
- `by` on everything a key writes is the key's identity, whatever the payload said, so the audit trail names the client.
- A key never sets a body's ship: identity is the owner's to assign.
- Deleting a body and merging one into another (`POST /merge`) are the owner's, over the cookie: a key asking for either is 403 `owner only`.
- A key may only relate what it can see. An observation whose value points at a body outside the key's kinds is refused, naming that body, so a key cannot confirm one by watching for an `existing` answer.
- A batch with one item outside the scope is refused whole, with the first offending id or attribute named. Nothing in it is written, including the items that were in scope.

## Sensitive attributes

`policy.json` starts with `"sensitive": ["health", "income"]`, the two attributes a triager puts medical and money facts under, and the owner may add to the list. A key never receives those attributes on any view, cannot observe them, and cannot retract them, whatever its scope. The owner cookie sees everything. A ship seeded before version 11 keeps its own policy; add the line there by hand.

A writing key can learn that a name is sensitive by trying to observe it and reading the refusal. It never learns the value.

## What to know

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
