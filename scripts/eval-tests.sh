#!/bin/bash
# eval-tests.sh <suite>: run one unit suite's test arms with vere eval, no ship.
# The lib imports nothing, so it builds against the ivory pill; the test
# lib's two gates are stood in for by ones that compare nouns. Prints the
# failing arms with what each expected and got, then the count.
set -euo pipefail
cd "$(dirname "$0")/.." 2>/dev/null || true
suite=$1; f=tests/lib/$suite.hoon; VERE=${VERE:-$HOME/software/vere-v4.6-linux-x86_64}
arms=$(grep -o '^++  test-[a-z0-9-]*' "$f" | sed 's/^++  //')
{
  echo '=>'; cat code/lib/orrery.hoon
  cat <<'HOON'
=/  orr  .
=/  gen  .
=>  |%
    ++  expect-eq
      |=  [expected=vase actual=vase]
      ^-  tang
      ?:  =(q.expected q.actual)  ~
      ~[leaf+"expected:" (sell expected) leaf+"actual:" (sell actual)]
    ++  expect
      |=  actual=vase
      ^-  tang
      ?:  =(%.y q.actual)  ~
      ~[leaf+"expected %.y, got:" (sell actual)]
    --
=/  t
HOON
  sed -n '/^|%$/,$p' "$f"
  echo '=/  results=(list [name=@tas fail=tang])'
  echo '  :~'
  for a in $arms; do echo "    [%$a $a:t]"; done
  echo '  =='
  echo '=/  failed  (skip results |=([name=@tas fail=tang] =(~ fail)))'
  echo '[ran=(lent results) failed=(turn failed |=([name=@tas fail=tang] [name (turn `wall`(zing (turn fail |=(t=tank (wash [0 120] t)))) crip)]))]'
} > /tmp/eval-tests-$suite.hoon
"$VERE" eval < /tmp/eval-tests-$suite.hoon 2>&1 | grep -v '^lite:\|^loom:\|^eval (run)'
