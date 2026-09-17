# Sharing a body with another ship

A body and its observations can be shared with another ship: read mode mirrors what you know onto their ship, edit mode also carries what they observe back onto yours. The unit is one body. Nothing else on the ship is visible to them.

## How it works

- `POST /apps/orrery/api/share` with `{"id": "person/sarah", "ship": "~feb", "mode": "read"}` (or `"edit"`) records the share in `shares.json`, lets `~feb` read the body's directory (a usergroup named `orrery-person-sarah` with one peek grant), and pokes an offer into `~feb`'s inbox. The answer's `notified` says whether the offer was acknowledged within thirty seconds; a false is worth a look at the other ship, not a retry.
- On `~feb`, `GET /apps/orrery/api/shares` lists `offers`, `accepted` and `shares` (what this ship shares out). `POST /api/accept` with `{"host": "~wex", "id": "person/sarah"}` takes an offer. The first hop assumes the other ship installed orrery at the standard desk path; a ship that did not answers `notified` false. When the shared body's `ship` is `~feb` itself, it lands on `person/me`; otherwise on a body with the same id, created with the offered name and ship if absent. `POST /api/decline` drops an offer.
- The follower runs every five minutes, on every accept and on `POST /api/sync`. It reads each accepted body whole from the host and submits the host's own observations to the local writer with `by` set to the host and `source` `{"kind": "ship", "id": "~wex/<host observation id>"}`. A row the host retracts is retracted here. A row the host itself mirrored from a third ship is not carried on: one hop.
- In edit mode the follower also sends the local observations on that body (the ones not mirrored from a ship) to the host's inbox, where they land with `by` set to the sender and the same source shape. Retractions travel the same way. The host's inbox checks the share record before it applies anything; the sender is the transport's, never the payload's.
- `DELETE /apps/orrery/api/share/person/sarah/~feb` removes the ship from the record and the group and tells the other ship, which drops the accepted row. Mirrored observations stay on both sides, still naming their source.

## What to know

- The ask grows by poke on `/sys/gall/`, `/sys/behn/`, `/sys/ames/registry` and `/sys/ames/usergroups/`, peek on `/sys/ames/usergroups/` and `/sys/ames/ships/`, make on `/sys/ames/usergroups/`. Refuse them and everything else keeps working; sharing is off.
- `{"ref"}` values travel verbatim. They name bodies on the ship that observed them. One that names the receiving body itself is refused by the writer and noted in the audit log.
- The name, aliases and ship of a shared body are copied once, at accept. Later changes to them do not follow; observations do.
- Every accepted row carries `last` (the last attempt, successful or not) and `error` (empty, or why the host could not be read or would not take the edits). In edit mode the host's acknowledgement means it received the rows, not that it kept them: rows sent after the host narrowed the share are dropped there and noted in its audit log.
- A share can be narrowed by the host at any time and it applies at once. Widening one (read to edit) is a new offer: nothing of yours leaves the ship until you accept it.
- A ship that is down does not stall the follower: a peek or a poke gives up after thirty seconds and the row records it.
