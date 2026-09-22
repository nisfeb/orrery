# Reading Tlon DMs and group channels on the ship

Orrery version 37 reads the owner's Tlon messages itself: DMs, group DMs and the group channels the owner picks. It runs them through the reader pipeline the Telegram reader has had since version 29 and writes the same facts under the same rules, so the phone client's chat reader can be switched off and the phone leaves the loop. Asked by the owner on 2026-09-21 after version 34; the research behind the shape is `.superpowers/research-tlon-reader.md` (2026-09-21, read-only survey of grubbery, Tlon's groups desk and the phone client).

## How the ship gets the messages

Polling, not subscribing. Grubbery lets a nexus scry a gall agent through `typed-scry` (fiberio, a poke to `/sys/scry/main.sig` answered with the raw noun), and when the scry path ends in `/json` gall converts the agent's answer through the groups desk's own mark before it comes back, which every chat and channels type has. Tlon exposes two "changes since a time" scries built for this: `/gx/chat/v4/changes/<since>/json` (every writ changed since, per DM or club, tombstones included) and `/gx/channels/v6/changes/<since>/json` (the same per channel). Two scries a pass cover everything, and orrery needs only its own `json` marc.

Subscribing (`%gall-watch` through the grubbery agent) was measured and declined: the facts land as raw nouns of Tlon's types, which would mean vendoring about 7,600 lines of Tlon's sur and json libraries that move with every Tlon release, plus a `/sys/gall/` peek road and the known subscription edges lattice hit. If five minutes ever proves too slow, a watch on `/v4` can be added later as a wake-up only, its contents ignored.

## The fiber

`chat.sig`, risen like the others, on a timer: every `poll_minutes` (5 unless set). Each pass:

1. `%gu` liveness scries for `chat` and `channels`; a ship without the groups desk notes `groups desk not installed` in the record and sleeps.
2. The two `changes` scries with `since` the last pass's time (`chat-last.json`; on first run, `since` is now minus `backfill_hours`, 24 unless set, and the pass reads only, filing nothing older than the setting, so an install does not triage a year of chat).
3. From the answers, the messages to read: for each DM or club in the settings' `dms` (a `whom` string, `~ship` or `0v...`) and each channel in `channels` (a nest, `chat/~host/name`), every writ or post whose `essay.sent` is after `since`, not a tombstone, not an edit of one already read (dedupe on `seal.id` in `chat-seen.json`, the way the Telegram reader drops a repeated update id), and not by the owner's own ship unless `read_own` is set. Replies count as messages, their parent's text as context. The text is the story's inline strings with `break` as a newline, ships as `~ship`, links as their text.
4. The same pipeline as `tg-handle`: the sender filter (`people`, a map from `@p` to a body id; a sender not in it is a stranger and is ignored, exactly as the Telegram reader ignores a user not in `people`; the owner's own ship maps to `person/me`), the daily cap, the gate through the decider, the analyst with the window (five per conversation, a day, `chat-recent.json`), validate, ground, the status check, the escalate question, filing through the writer, an urgent pass on a yes. Facts are signed `chat`, source kind `chat`, source id `chat/<whom or nest>/<seal.id>`, which is the id the phone client's reader uses, so the two never triage a message twice.
5. `chat-last.json` moves to this pass's `now` only after every message of the pass is filed, so a model outage leaves them for the next pass, as the Telegram reader keeps an update.

The `Channel:` line the analyst reads is `chat`, so a message the model proposes goes `via` `chat` (the channel rule of version 36 agrees: a person on Tlon has a ship).

## Settings

`chat.json`, owner-only, through `GET`/`PUT /api/chat` and a Chat card under Settings beside the Telegram card, and reachable through the same routes by a key with `write` so the phone client can set them: `enabled`, `dms` (a list of `whom` strings; the card offers the ship's DM list from `/gx/chat/dm/json` as checkboxes), `channels` (a list of nests; the card lists the ship's channels from `/gx/channels/v5/channels/json` or the groups scry the research names, with the group's title), `people` (`@p` to body id; the card seeds it with every person body that carries a `ship` attribute and lets the owner add a row), `read_own`, `poll_minutes`, `backfill_hours`, `gate`, `escalate`, `max_daily_messages`, the reader's model (the Telegram reader's, `deepseek/deepseek-v4-flash`, unless set). The card shows the last pass: time, messages read, facts filed, strangers ignored, the cap, and a wake button (`POST /api/chat/wake`).

A person with a `ship` attribute is in `people` without a row: the fiber merges the attribute map over the settings' map each pass, settings winning, so the owner maintains one thing.

## Consent

One new road: `/sys/scry/` (poke), with the line `read your Tlon messages (DMs and the group channels you pick) so what people tell you on Urbit becomes facts the ship knows; refuse this and the ship reads no chat`. The owner approves it on the permits page at release.

## Limits and safety

The same as the Telegram reader: `max_daily_messages` (500), the model calls through the generator's key and provider rule, message text kept only in the window file, never in a view or a prompt other than the reader's. A `changes` answer over 1 MB is read for its ids and skipped for its text with a note (a busy channel after a long gap), and the next pass starts where `since` left it. The scries run one at a time; a `%gx` that bails is caught by the `%gu` check first, and a `/sys/scry/` veto leaves the fiber alive with a note.

## the phone client's side (a separate prompt)

When 37 is live and the owner has picked DMs and channels on the card, the phone client stops reading chats into facts (its reader for Urbit chats and mail into facts; the mail reader stays until auspex mail is read on the ship, a later version). The phone client may still write the settings through `PUT /api/chat`.

## Out of scope

Auspex mail on the ship (later). Sending `via: chat` from the ship (The phone client's). Reading images, polls or reactions. A watch subscription for lower latency (a later addition if wanted).
