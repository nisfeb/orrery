# Keys for clients that do not run a ship

A key is a token for one client: a name, the identity it writes as, and a scope. The owner mints it and sees the secret once. Requests carry it as `Authorization: Bearer <token>` with no cookie.

## Minting and revoking

- `POST /apps/orrery/api/clients` with `{"name": "Talon on the phone", "by": "talon", "scope": {"kinds": ["person", "thing", "place", "situation"], "actions": [], "write": true}}` answers the row and the `token` once. Store it in the client; the ship keeps only a salted hash.
- `GET /apps/orrery/api/clients` lists the keys with their scope, when they were made and last used (to the hour), never the secret.
- `DELETE /apps/orrery/api/clients/<id>` revokes one. The next request with it is refused.

## What a scope means

- `kinds`: the body kinds the key may see. The state, body and resolve views omit every other body, and a body outside them answers exactly what a missing body answers. With `write`, the key may observe those bodies and create them.
- `actions`: the action kinds the key may propose and list. With `write`, it may also approve, dismiss and complete them.
- `write`: false makes the key read-only: it cannot observe, create bodies, retract or transition an action. Proposing needs only the action kind, so a read-only key with `actions` can still file a proposal for the owner to approve.
- `by` on everything a key writes is the key's identity, whatever the payload said, so the audit trail names the client.
- A batch with one item outside the scope is refused whole, with the first offending id or attribute named.

## Sensitive attributes

`policy.json` may carry `"sensitive": ["health", "income"]`. A key never receives those attributes on any view, cannot observe them, and cannot retract them, whatever its scope. The owner cookie sees everything.

## What to know

- The owner cookie is never scoped. Keys are checked in the app, not by eyre, the way calendar checks CalDAV passwords.
- A key learns nothing about bodies outside its kinds: not their names, not that they exist, not through an action's `about` (trimmed to the key's kinds), not through an attribute whose value points at one (the key reads that attribute as cleared, never as an older value; a veiled row looks exactly like one the owner cleared). Only a top-level `{"ref"}` value is veiled; a body id written inside free-form JSON is not.
- Last use is recorded at most once an hour per key.
- At most 50 keys; scope lists of at most 24 kinds each.
