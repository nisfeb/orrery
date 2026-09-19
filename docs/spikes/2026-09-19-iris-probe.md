# Spike: how long will iris wait for a model?

The question before the generator moves into Hoon: can a desk hold an outbound HTTPS request open for the minutes a reasoning model takes? The calendar desk already POSTs through `/sys/iris/` (`fetch-hdr` in its app.hoon), and what it shows is that **the ceiling is the app's own timer**: iris carries no request id and no timeout of its own, so the fiber sets a behn timer and answers status 0 when the timer wins. The calendar uses two minutes. The runtime side is the open question: whether the connection itself survives a five-minute wait.

Run it on `~wex`, never on ricsul.

## Result, 2026-09-19

Run twice on `~wex` (orrery 17, the probe route written into the desk's code tree and taken out again afterwards):

| request | status | seconds |
|---|---|---|
| DeepSeek V4 Pro, a combinatorics question, reasoning high | 200 | 6 |
| DeepSeek V4 Pro, a 6,000-word essay, 16,000-token cap | 200 | 259 |

The runtime held a four-minute outbound request through iris and delivered the whole body (OpenRouter sends keepalive whitespace while it generates, which is what the head of the answer shows). So the ceiling is the app's own timer, not the runtime, and the on-ship generator can run any model at any reasoning level under a ten minute timer. Nothing about streaming or smaller budgets is needed.

Two things learned about the fast loop on the way: a forge pull does not put a `write-text` edit back, because the version gate sees 17 = 17 and syncs nothing, so the restore is another `write-text` of the committed file; and the ball's data tree has no delete action, so `probe.json` was overwritten with `{}` rather than removed.

## 1. The key and the request, as a data file

Write `probe.json` into the instance's data tree, owner cookie, without printing the key:

```sh
python3 - <<'EOF'
import json, subprocess
c = json.load(open('/home/sneagan/software/personal/orrery-utils/config.json'))['model']
body = {"model": "deepseek/deepseek-v4-pro", "max_tokens": 16000,
        "reasoning": {"effort": "high"}, "provider": {"zdr": True},
        "messages": [{"role": "user", "content": "Think as long as you need, then answer: how many distinct ways can 12 people be seated at a round table if two particular people must not sit together? Show the reasoning."}]}
probe = {"url": c["url"].rstrip("/") + "/chat/completions", "api_key": c["api_key"], "body": body}
base = "http://localhost:8080/grubbery/ball/apps/shell.shell/desks/orrery.desk/desk/data/orrery.orrery_app"
subprocess.run(["curl", "-s", "-b", "/tmp/wex.cookies", "-X", "POST", base, "--data-urlencode", "action=create-file", "--data-urlencode", "filename=probe.json"], check=False)
subprocess.run(["curl", "-s", "-b", "/tmp/wex.cookies", "-X", "POST", base + "/probe.json", "--data-urlencode", "action=write-text", "--data-urlencode", "content=" + json.dumps(probe)], check=True)
print("probe.json written")
EOF
```

DeepSeek V4 Pro with high reasoning ran 200 seconds in the bench, which is the length we want to see survive.

## 2. The probe route, into wex's copy of app.hoon only

Three edits to `code/nex/orrery/app.hoon`, written with `write-text` to the desk's code tree (never committed):

The road, in `weir-json`'s poke list:

```hoon
          (line '/sys/iris/' 'ask a model over HTTPS: the probe')
```

The route, before `(send-err eyre-id 404 'no such route')`:

```hoon
  ?:  &(=('POST' meth) ?=([%api %probe-iris ~] suffix))     (own (serve-probe-iris eyre-id))
```

The arm, next to `serve-clients`. It is the calendar's `fetch-hdr` with a ten minute timer and the elapsed time in the answer:

```hoon
::  +serve-probe-iris: one outbound POST from probe.json, timed. The
::  spike behind moving the generator on-ship: how long a request may
::  wait. The timer is the app's; iris has none of its own.
::
++  serve-probe-iris
  |=  eyre-id=@ta
  =/  m  (fiber:fiber:nexus ,~)
  ^-  form:m
  ;<  probe=json  bind:m  (read-json (rf 1 / %'probe.json'))
  =/  url=@t  (gs:orr probe 'url')
  =/  key=@t  (gs:orr probe 'api_key')
  =/  body=@t  (en:json:html (gj:orr probe 'body'))
  ?:  |(=('' url) =('' key))  (send-err eyre-id 400 'probe.json needs url and api_key')
  =/  =request:http
    :^  %'POST'  url
      :~  ['content-type' 'application/json']
          ['authorization' (cat 3 'Bearer ' key)]
      ==
    `(as-octs:mimes:html body)
  ;<  t0=@da  bind:m  get-time:io
  ;<  ~  bind:m  (send-request:io request)
  ;<  ~  bind:m  (set-timer:io /probe (add t0 ~m10))
  ;<  res=(unit client-response:iris)  bind:m
    |=  input:fiber:nexus
    :+  ~  q.state
    ?+  in  [%skip ~]
        ~  [%wait ~]
        [~ %veto *]  [%done ~]
        [~ %poke * *]
      ?:  =([/ %timer-wake] p.sage.u.in)
        ?.(?=([%probe *] !<(path q.sage.u.in)) [%skip ~] [%done ~])
      ?.  =([/ %http-response] p.sage.u.in)  [%skip ~]
      =/  resp=client-response:iris  !<(client-response:iris q.sage.u.in)
      ?:(?=(%cancel -.resp) [%done ~] [%done `resp])
    ==
  ;<  ~  bind:m  (cancel-timer:io /probe)
  ;<  t1=@da  bind:m  get-time:io
  =/  secs=@ud  (div (sub t1 t0) ~s1)
  =/  status=@ud
    ?~  res  0
    ?.(?=(%finished -.u.res) 0 status-code.response-header.u.res)
  =/  head=@t
    ?~  res  'no answer before the timer'
    ?.  ?=(%finished -.u.res)  'not finished'
    ?~(full-file.u.res '' (end [3 400] q.data.u.full-file.u.res))
  %^  send-json  eyre-id  200
  %-  pairs:enjs:format
  :~  ['status' (numb:enjs:format status)]
      ['seconds' (numb:enjs:format secs)]
      ['head' s+head]
  ==
```

If `client-response:iris` or `request:http` are not in scope in orrery's build the way they are in the calendar's, copy the calendar's imports for them.

## 3. Consent, compile, run

1. Write the file: `POST <ball>/desk/code/nex/orrery/app.hoon` with `action=write-text`, then read `?info=1`: `bang: null` compiles.
2. The new road needs the owner's consent on wex: approve the weir on the grubbery permits page (the same step ricsul's install went through), then reload the nexus.
3. `curl -s -m 700 -b /tmp/wex.cookies -X POST http://localhost:8080/apps/orrery/api/probe-iris` and read `status`, `seconds`, `head`.
4. `POST /grubbery/forge/api/run {"repo":"orrery.git_repo","command":"pull"}` on wex puts the committed code back. Delete `probe.json` with the ball API.

## What the numbers mean

- `status 200`, `seconds` about 200: the runtime holds the connection; the on-ship generator can run any model with any reasoning, with its own ten minute timer.
- `status 0` well before 600: the connection dropped; note the seconds. That is the ceiling, and the generator must fit under it, which means medium reasoning or a smaller budget, or streaming.
- No answer at 600: the timer won; iris lost the request. Same conclusion as status 0, at ten minutes.
