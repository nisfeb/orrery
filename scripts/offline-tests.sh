#!/usr/bin/env bash
# offline-tests.sh: run the Hoon suites in tests/lib through vere eval,
# with no ship (scripts/hoon-test-kit/offline-test.py), all at once.
# Each suite builds the 12k-line model, so each takes about a minute; in
# parallel the three take about a minute. The ship run (TESTING.md) stays
# the verdict.
#
#   scripts/offline-tests.sh                  every suite
#   scripts/offline-tests.sh orrery nexus     by name, no .hoon
set -uo pipefail
cd "$(dirname "$0")/.."
if (($#)); then names=("$@"); else
  names=(); for f in tests/lib/*.hoon; do names+=("$(basename "$f" .hoon)"); done
fi
tmp=$(mktemp -d); trap 'rm -rf "$tmp"' EXIT
pids=()
for n in "${names[@]}"; do
  python3 scripts/hoon-test-kit/offline-test.py "tests/lib/$n.hoon" > "$tmp/$n" 2>&1 &
  pids+=($!)
done
fail=0
for i in "${!names[@]}"; do
  n=${names[i]}; wait "${pids[i]}"; rc=$?
  printf '%-12s %s\n' "$n" "$(tail -1 "$tmp/$n")"
  ((rc == 0)) || { fail=1; sed -n '1,40p' "$tmp/$n"; }
done
exit $fail
