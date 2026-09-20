# Telegram on the ship

The Telegram reader moves from `orrery-utils/telegram/bot.py`, a Python script on a box, into orrery itself. Version 29 is the reader; version 30 will be the sender and the command replies. Decided with the owner on 2026-09-20: a script on a box is not urbity, and a webhook removes every reason the reader had to be one.

## What changes

Telegram pushes each update to the ship over HTTPS (`setWebhook`, with a secret header). The ship runs the same pipeline the bot runs today, with the same prompts and the same rules, and writes the same facts under the same source pointers. The Python bot stays in orrery-utils as the backfill and dry-run harness, and as the reader for anyone who does not run a ship.

## What stays the same

- The ship stores facts, never messages. The one exception is the context window: the last five free-text messages per chat, text included, in the reader's own data file, dropped after a day, never in any view, key, share or prompt other than the reader's own. That window exists on the box today in `state.json`; only where it sits changes.
- The prompts are the shared files: `orrery-utils/common/analyst-prompt.md` word for word, and the decider questions as `analyze.py` states them. Talon reads the same files.
- The rules of the client guide, 1 to 16, hold for the ship's own reader as they hold for any client: never triage a message twice, resolve before you create, the schedule is not the fact, a status is a circumstance, the message window, replay safety, dismissal reasons, the calendar action rules, the escalate question.
- Facts are signed `telegram`, source kind `chat`, source id `telegram/<chat id>/<message id>`, exactly as the bot signs them, so a backfill from an export and the live reader agree on what was read.

## Shape

- `POST /apps/orrery/telegram`: the webhook. Answered before `identify`: no cookie, no key, the secret header alone. The update is written to an inbox grub and the request answers 200 at once; Telegram gives up on a slow answer and resends.
- `telegram.sig`: a fiber that keeps a subscription on the inbox, drains it in update order, and runs the pipeline for each: the sender and chat filters, the command grammar (`/at`, `/status`, `/obs`, `/task`), else the gate through the decider, the analyst through the model, validation and grounding, the status check and the escalate question through the decider, then filing through the writer and, on a yes, an urgent pass through the generator fiber. It remembers the message in the window last.
- `telegram.json`: the settings, owner-only, the token and the secret masked on read like the generator's key. Chats, people, the reader's model, thresholds, a daily cap on messages read, the public URL for the webhook.
- `POST /api/telegram/webhook`: the owner tells the ship to register its webhook with Telegram; the ship calls `setWebhook` itself and answers what Telegram said.
- A Telegram card under Settings.

## Limits

- `max_daily_messages` (500 unless set): a chatty group cannot run the model all day. Past the cap an update is noted and dropped, not queued.
- The model calls use the generator's OpenRouter key and provider rule (`{"zdr": true}`) and the reader's own model, a small one; the decider is `typesafe/jev-1.13` through the decisions route with the same key.
- Business messages (Telegram Premium) arrive on the same webhook. A connection whose owner is not in `people` is ignored, checked once per connection through `getBusinessConnection` and remembered.

## Out of scope for version 29

Sending: replies to commands, the `via: telegram` executor. Version 30. Until then an approved `via: telegram` message is still sent by the Python bot's executor if it runs, or waits.
