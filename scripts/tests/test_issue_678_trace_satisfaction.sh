#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENGINE="$ROOT/.claude/hooks/rule-engine.sh"
TMP_ROOT=$(mktemp -d)
trap 'rm -rf "$TMP_ROOT"' EXIT

PROTOCOL="$TMP_ROOT/protocol-close.md"
cat > "$PROTOCOL" <<'EOF'
# Close

## Quick Close (session)

```bash
# A heading inside code must not end the section. [[gate]]
```

## ЧАСТЬ А

### Save [[gate:AR.005]]

Do the work. [[gate]]

The literal marker `[[gate]]` is documentation, not a gate.

### Verify [[gate:AR.007]]

## Week Close

### Backup [[gate]]
EOF

export RULE_TRACE_STATE_DIR="$TMP_ROOT/state"
export RULE_TRACE_SESSION_ID="session-a"

mapfile -t gates < <(bash "$ENGINE" list-gates --protocol "$PROTOCOL" --section "Quick Close")
[ "${#gates[@]}" -eq 2 ]
[[ "${gates[0]}" == *:AR.005 ]]

set +e
before=$(bash "$ENGINE" check-trace-satisfaction --protocol "$PROTOCOL" --section "Quick Close")
before_rc=$?
set -e
[ "$before_rc" -eq 2 ]
python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"] == "block" and d["required"] == 2 and d["satisfied"] == 0' <<< "$before"

for gate in "${gates[@]}"; do
    bash "$ENGINE" mark-gate "$gate" --protocol "$PROTOCOL" --section "Quick Close" >/dev/null
done

after=$(bash "$ENGINE" check-trace-satisfaction --protocol "$PROTOCOL" --section "Quick Close")
python3 -c 'import json,sys; d=json.load(sys.stdin); assert d["verdict"] == "ok" and d["satisfied"] == 2 and d["missing"] == []' <<< "$after"

export RULE_TRACE_SESSION_ID="session-b"
set +e
other_session=$(bash "$ENGINE" check-trace-satisfaction --protocol "$PROTOCOL" --section "Quick Close")
other_rc=$?
set -e
[ "$other_rc" -eq 2 ]
python3 -c 'import json,sys; assert json.load(sys.stdin)["satisfied"] == 0' <<< "$other_session"

export RULE_TRACE_SESSION_ID="session-a"
sed -i 's/Do the work\. \[\[gate\]\]/Do the work safely. [[gate]]/' "$PROTOCOL"
set +e
changed=$(bash "$ENGINE" check-trace-satisfaction --protocol "$PROTOCOL" --section "Quick Close")
changed_rc=$?
set -e
[ "$changed_rc" -eq 2 ]
python3 -c 'import json,sys; assert json.load(sys.stdin)["satisfied"] == 0' <<< "$changed"

set +e
bash "$ENGINE" mark-gate "made-up-key" --protocol "$PROTOCOL" --section "Quick Close" >/dev/null
unknown_rc=$?
set -e
[ "$unknown_rc" -eq 3 ]

echo "trace-satisfaction tests passed"
