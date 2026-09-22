# Executors on the ship

Orrery version 34 carries out its own approved actions. The ship sends a `message` over Telegram or auspex mail, puts a `calendar` action on the calendar and a `task` in the todo list, and keeps the todo list and the actions in step. The phone client stops doing those four things and keeps what only a phone can do: reading Urbit chats and mail into facts, location, the morning brief, the inbox with tap-to-approve, and sending `via: chat`, whose store is the phone client's own. Decided with the owner on 2026-09-21, together with two simplifications: the reader has no command grammar (a slash message is read as text), and the ship never replies in a Telegram chat except to deliver an approved message.

## Why on the ship

An approval today waits for the phone client's ten-minute pass on a phone that may be asleep. The three targets are all on the ship already: the Telegram token (version 29), the calendar desk and auspex. The ship can act the moment the beacon moves, and the calendar can tell the ship the moment a todo is ticked.

## The executor fiber

`exec.sig` keeps orrery's beacon, the way `gen.sig` does. On each change it reads the open actions and takes each one it can serve:

- `message` with `via` `telegram`: the chat id is the person's `telegram` attribute; one `sendMessage` through the reader's token.
- `message` with `via` `mail`: the address is the person's `ship` attribute (auspex is mail between ships; there is no email in it); a `send` poke to auspex's writer with the action's title as the subject and the payload's text as the body.
- `calendar`: an `add-event` poke to the calendar's writer, `cat` `timed` with `start_ms`/`end_ms` from the payload's `starts`/`ends`, or `allday` when both are whole days, `meta.name` the payload's title, `meta.orrery` the action id, `meta.tags` `["orrery"]`, `meta.location` when given.
- `task`: an `add-event` poke with `cat` `todo`, `meta.name` the action's title, `meta.note` the payload's notes, `due_ms` from `due`, `meta.orrery` the action id, `meta.tags` `["orrery"]`.

Each one is claimed first through the writer with `by` `ship`, the claim read back, and the action moved to `done` with a note (`sent to <chat>`, `sent by mail to <ship>`, `on the calendar`, `in the todo list`) or `failed` with the reason (`person/x has no telegram attribute`, `no ship attribute`, Telegram's own error text, `the calendar is not installed`). A claim another executor holds is left alone; that is the claim protocol's job and it already works. An action whose kind the ship cannot serve (`chat`, `home`, `note`) is not touched.

A task that is `done` on the ship before the fiber ever saw it (the owner ticked it on the page) gets no todo.

## The mirror

The fiber also keeps the calendar's store grub. On a change it reads every todo:

- A todo with `meta.orrery` whose action is `done` and whose todo is not done gets `done-event`; whose action is `dismissed` or `failed` gets `del-event`; whose `due` differs from the action's `due` gets `edit-event` toward the action (the ship is the source of truth for what it made).
- A todo with `meta.orrery` that is done in the calendar and whose action is `approved` or `claimed` moves the action to `done` with the note `ticked in the calendar`.
- A todo with no `meta.orrery` and not done is the owner's own: it becomes an approved `task` on the ship (`by` `calendar`, source `{"kind": "calendar", "id": <todo id>}`) and the todo is then given `meta.orrery` and the tag through `edit-event`, so it is read once. Its title is the todo's name, its due the todo's due.
- Events that are not todos are never touched: the calendar pipe that turns events into situations is reading, and stays with the phone client.

Both halves are pure planners in the lib over the actions and the calendar's todo list, answering writer ops and calendar pokes; the fiber files them.

## Discovery and consent

Orrery asks `/sys/link/` where `calendar.desk` and `auspex.desk` are installed and pokes those instances' writers (`main.sig`) and keeps the calendar's store (`calendar.calendar`). Three roads join the consent list: `/sys/link/`, the calendar's instance (poke its writer, keep its store) and auspex's writer. The owner approves them once on the permits page. A desk that is not installed, or a road that is refused, is noted once in the record and that action kind is left for other executors; nothing jams and nothing is retried in a loop.

## Limits and safety

- One claim per action, ever, by this fiber: an action it claimed and then failed is not retried by it (the owner sees `failed` and the reason, and can approve a new one).
- A Telegram or auspex refusal is `failed` with the text; the fiber moves on.
- The mirror writes nothing for a todo it did not make and the owner did not type (a todo made by another orrery client with `meta.orrery` set is treated as the ship's own, since the id is the action id either way).
- Message text leaves the ship only as an approved payload's text.

## The record and the card

`exec-last.json`: the last pass's time, what was sent, put on the calendar, mirrored (todos ticked, deleted, adopted), failed with reasons, and which roads are missing. A card under Settings with those counts, the missing roads, and a wake button.

## Version 29's reader, simplified

`tg-command` and its test go. Every message is free text. The reader still writes facts and asks for urgent passes; it sends nothing. The client guide's rule 14 says the ship's executor takes `telegram`, `mail`, `calendar` and `task`, that `mail` addresses a ship, and that a client executor takes `chat` only.

## the phone client's side (a separate prompt)

Remove the task mirror (OrreryTasks), the calendar action placement, the Telegram and mail senders, and the `via` branches other than `chat`; keep the calendar pipe (events to situations), the reader, location, the brief and the inbox. Release in step with version 34, since two mirrors must not overlap.

## Out of scope

Sending `via: chat` from the ship (The phone client's store). Replies to Telegram commands (there are no commands). Reading calendar events into situations on the ship (The phone client's pipe).
