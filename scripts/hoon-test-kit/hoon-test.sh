#!/usr/bin/env bash
# hoon-test-kit: run an app's Hoon suites on a running fake ship, on a desk
# that holds nothing but the libs under test and their tests. See README.md
# and PLAYBOOK.md.
#
#   hoon-test.sh <pier> setup          once per ship, after |new-desk + |mount
#   hoon-test.sh <pier> [suite ...]    sync, commit, test
#
# The app is described by hoon-test.conf, found in the current directory or
# the nearest one above it (or at $HOON_TEST_CONF); paths in it are relative
# to it. A suite is a test file's name without .hoon; none runs them all.
#
# Exits 0 when every test passes, 1 when one fails, 3 when a lib does not
# build, 4 when the ship does not answer. Per-test OK/FAILED lines are
# slogged to the ship's terminal: the socket only carries the verdict.
set -euo pipefail

conf=${HOON_TEST_CONF:-}
if [[ -z "$conf" ]]; then
  d=$PWD
  while [[ "$d" != / && ! -f "$d/hoon-test.conf" ]]; do d=$(dirname "$d"); done
  conf="$d/hoon-test.conf"
fi
[[ -f "$conf" ]] || { echo "no hoon-test.conf here or above" >&2; exit 2; }
root=$(cd "$(dirname "$conf")" && pwd)
MARKS="json mime" FILES=""
# shellcheck source=/dev/null
source "$conf"
: "${DESK:?hoon-test.conf sets DESK}" "${LIBS:?hoon-test.conf sets LIBS}" "${TESTS:?hoon-test.conf sets TESTS}"

pier=$(cd "${1:?usage: hoon-test.sh <pier> [setup | suite ...]}" && pwd); shift
sock="$pier/.urb/conn.sock"
# the runtime is only used for its jam/cue framing: $VERE, or the newest
# vere-* sitting beside the pier
VERE=${VERE:-$(ls -d "$(dirname "$pier")"/vere-*-linux-x86_64 2>/dev/null | sort -V | tail -1)}
[[ -x "$VERE" ]] || { echo "no vere binary: set VERE" >&2; exit 2; }

# repo -> desk: each LIBS file to lib/<name>.hoon, each TESTS/*.hoon to
# tests/lib/, each FILES entry to the same path (or src=dest). Output is
# rsync's itemised list, so empty means nothing changed.
sync() {
  local d="$pier/$DESK" f src dst
  mkdir -p "$d/lib" "$d/tests/lib"
  for f in $LIBS; do rsync -ci "$root/$f" "$d/lib/"; done
  rsync -ci "$root/$TESTS"/*.hoon "$d/tests/lib/"
  for f in $FILES; do
    src=${f%%=*}; dst=${f#*=}
    mkdir -p "$d/$(dirname "$dst")"
    rsync -ci "$root/$src" "$d/$dst"
  done
}

# Run hoon (a strand producing a vase) in a khan thread over conn.sock and
# print the product noun. The hoon rides as a cord, so it holds no ', and
# on one line, so every newline becomes a two-space gap: one space is not
# a gap, and the parse fails.
# No answer at all is exit 4, never a test verdict: a ship that crashed
# mid-run must not read as a failing suite (or a killed mutant).
ted() {
  local hoon out; hoon=$(sed ':a;N;$!ba;s/\n/  /g')
  out=$(printf '%s\n' "[0 %fyrd [%base %khan-eval %noun [%ted-eval '$hoon']]]" |
    "$VERE" eval --jam -n 2>/dev/null |
    socat -T "${T:-60}" -,ignoreeof UNIX-CONNECT:"$sock" 2>/dev/null |
    "$VERE" eval --cue -n 2>/dev/null | tail -1 |
    sed -E 's/^\[0 %avow 0 %noun (.*)\]$/\1/' |
    # a failed thread's tang arrives as [%leaf <bytes> 0]: make it text
    perl -pe 's/\[%leaf ((?:\d+ )*)0\]/join "", map chr, split " ", $1/ge') || true
  [[ -n "$out" ]] || { echo "the ship at $pier did not answer" >&2; return 4; }
  echo "$out"
}

hash() { ted <<EOF
=/  m  (strand ,vase)
;<  h=@uvI  bind:m  (scry @uvI /cz/$DESK)
(pure:m !>(h))
EOF
}

if [[ "${1:-}" == setup ]]; then
  # |new-desk %$DESK and |mount %$DESK in the dojo first: both are one
  # line there. This copies the test harness and the MARKS the suites
  # need in from the ship's own %base, so they always match its kelvin;
  # a file already on the desk is left alone, so setup can be rerun.
  # %json builds through its grad mark, %mime: without it a /* of a json
  # file fails the whole suite as a build error.
  marks=""
  for k in $MARKS; do marks+=" /mar/$k/hoon"; done
  ted >/dev/null <<EOF
=/  m  (strand ,vase)
=/  paz=(list path)  ~[/lib/test/hoon$marks]
=|  fil=soba:clay
|-
?^  paz
  ;<  has=?  bind:m  (scry ? (weld /cu/$DESK i.paz))
  ?:  has  \$(paz t.paz)
  ;<  t=@t  bind:m  (scry @t (weld /cx/base i.paz))
  \$(paz t.paz, fil [[i.paz %ins %hoon !>(t)] fil])
;<  ~  bind:m  (send-raw-card [%pass /setup %arvo %c %info %$DESK %& fil])
(pure:m !>(%ok))
EOF
  echo "setup done: /lib/test.hoon and the marks are on %$DESK"
  exit
fi

# NOSYNC=1 commits the mount as it stands: how hoon-mutate.py runs the
# suites against a mutant it wrote there, which a sync would overwrite.
if [[ -n "${NOSYNC:-}" || -n "$(sync)" ]]; then
  before=$(hash)
  ted >/dev/null <<EOF
=/  m  (strand ,vase)
;<  =bowl  bind:m  get-bowl
;<  ~  bind:m  (poke [our.bowl %hood] kiln-commit+!>([%$DESK |]))
(pure:m !>(%ok))
EOF
  # the commit lands as a later event than the poke's ack
  for _ in $(seq 60); do [[ "$(hash)" != "$before" ]] && break; sleep 1; done
fi

libs=""
for l in $LIBS; do l=${l##*/}; libs+=" /lib/${l%.hoon}/hoon"; done
paths=""
for s in "${@:-}"; do paths+=" [(scot %p our.bowl) %$DESK (scot %da now.bowl) %tests %lib${s:+ %$s} ~]"; done
# the libs are built first, so a lib that does not compile is its own
# answer rather than one more FAILED test file
ok=$(T=${TEST_T:-600} ted <<EOF
=/  m  (strand ,vase)
;<  =bowl  bind:m  get-bowl
=/  libs=(list path)  ~[${libs# }]
|-
?^  libs
  ;<  v=(unit vase)  bind:m  (build-file [[our.bowl %$DESK da+now.bowl] i.libs])
  ?~  v  (pure:m !>(2))
  \$(libs t.libs)
;<  r=thread-result  bind:m  (await-thread %test !>([~ \`(list path)\`~[${paths# }]]))
?:  ?=(%| -.r)  (pure:m !>(%crash))
(pure:m !>(!<(? p.r)))
EOF
)
case "$ok" in
  0) echo "hoon tests passed" ;;
  1) echo "hoon tests FAILED (names are in the ship's terminal)"; exit 1 ;;
  2) echo "a lib did not build"; exit 3 ;;
  *) echo "hoon test run did not complete: $ok"; exit 2 ;;
esac
