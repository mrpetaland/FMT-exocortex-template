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

Instruction version one.

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

default_protocol=$(RULE_PROTOCOL="$PROTOCOL" bash "$ENGINE" list-gates --section "Quick Close")
[ "$default_protocol" = "$(printf '%s\n' "${gates[@]}")" ]

export RULE_TRACE_SESSION_ID="session-b"
set +e
other_session=$(bash "$ENGINE" check-trace-satisfaction --protocol "$PROTOCOL" --section "Quick Close")
other_rc=$?
set -e
[ "$other_rc" -eq 2 ]
python3 -c 'import json,sys; assert json.load(sys.stdin)["satisfied"] == 0' <<< "$other_session"

export RULE_TRACE_SESSION_ID="session-a"
sed -i 's/Instruction version one\./Instruction version two./' "$PROTOCOL"
set +e
changed=$(bash "$ENGINE" check-trace-satisfaction --protocol "$PROTOCOL" --section "Quick Close")
changed_rc=$?
set -e
[ "$changed_rc" -eq 2 ]
python3 -c 'import json,sys; assert json.load(sys.stdin)["satisfied"] == 0' <<< "$changed"

SAME_NAME_DIR="$TMP_ROOT/other"
mkdir -p "$SAME_NAME_DIR"
cp "$PROTOCOL" "$SAME_NAME_DIR/protocol-close.md"
mapfile -t other_gates < <(bash "$ENGINE" list-gates --protocol "$SAME_NAME_DIR/protocol-close.md" --section "Quick Close")
[ "${other_gates[0]}" != "${gates[0]}" ]
set +e
same_name=$(bash "$ENGINE" check-trace-satisfaction --protocol "$SAME_NAME_DIR/protocol-close.md" --section "Quick Close")
same_name_rc=$?
set -e
[ "$same_name_rc" -eq 2 ]
python3 -c 'import json,sys; assert json.load(sys.stdin)["satisfied"] == 0' <<< "$same_name"

PORTABLE_BIN="$TMP_ROOT/portable-bin"
mkdir -p "$PORTABLE_BIN"
for command_name in awk cp date dirname mkdir python3 shasum; do
    command_path=$(command -v "$command_name")
    ln -s "$command_path" "$PORTABLE_BIN/$command_name"
done
mapfile -t portable_gates < <(PATH="$PORTABLE_BIN" /bin/bash "$ENGINE" list-gates --protocol "$PROTOCOL" --section "Quick Close")
[ "${#portable_gates[@]}" -eq 2 ]

NO_HASH_BIN="$TMP_ROOT/no-hash-bin"
mkdir -p "$NO_HASH_BIN"
for command_name in awk date dirname mkdir python3; do
    command_path=$(command -v "$command_name")
    ln -s "$command_path" "$NO_HASH_BIN/$command_name"
done
set +e
no_hash=$(PATH="$NO_HASH_BIN" /bin/bash "$ENGINE" check-trace-satisfaction --protocol "$PROTOCOL" --section "Quick Close" 2>/dev/null)
no_hash_rc=$?
set -e
[ "$no_hash_rc" -eq 3 ]
python3 -c 'import json,sys; assert json.load(sys.stdin)["verdict"] == "error"' <<< "$no_hash"

set +e
bash "$ENGINE" mark-gate "made-up-key" --protocol "$PROTOCOL" --section "Quick Close" >/dev/null
unknown_rc=$?
set -e
[ "$unknown_rc" -eq 3 ]

echo "trace-satisfaction tests passed"
