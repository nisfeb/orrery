# orrery

A model of one person's world, kept on their Urbit ship as a grubbery desk app. The people, places, things and situations around them, what is currently true about each, where every fact came from, and what the assistant proposes to do about it.

The ship holds the state and its history and runs no AI. Clients triage messages, mail and calendar events into observations and submit them; a larger model reads the state back and proposes actions, or files them straight to the todo list when policy allows.

- Design: `docs/superpowers/specs/2026-09-16-orrery-design.md`. Phase 1 plan: `docs/superpowers/plans/2026-09-16-orrery-phase-1.md`. Sharing: `docs/sharing.md`. Keys: `docs/keys.md`.
- `code/` is the desk: the nexus at `code/nex/orrery/app.hoon`, the model in `code/lib/orrery.hoon`, the marcs under `code/mar`. `code/version.json` is what replicates.
- The HTTP API lives under `/apps/orrery/api`: `state`, `body/<kind>/<slug>`, `resolve`, `observe`, `retract`, `bodies`, `act`, `actions`, `schema`, `policy`, `share`, `shares`, `accept`, `decline`, `share/<id>/<ship>`, `sync`, `clients`, `clients/<id>`. The owner cookie or a minted key. Spec section 6 has the table.
- Gates, against `~wex`: `tests/lib/orrery.hoon` with `-test`, `scripts/api-matrix.py`, and `scripts/key-matrix.py`. Against `~wex` and `~feb`: `scripts/ship-share-matrix.py`. Releasing: `docs/releasing.md`.
- Family: [lattice](https://github.com/nisfeb/lattice), [auspex](https://github.com/nisfeb/auspex), [calendar](https://github.com/nisfeb/calendar), installed from `~ricsul-bilwyt` the same way.
