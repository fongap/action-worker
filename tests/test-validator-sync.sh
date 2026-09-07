#!/usr/bin/env bash
# 验证：.github/workflows/task-handler.yml 中的 inline validator
# 与 scripts/validate-payload.sh 保持一致。

set -u
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
WORKFLOW="$ROOT/.github/workflows/task-handler.yml"
SCRIPT="$ROOT/scripts/validate-payload.sh"

if [ ! -f "$WORKFLOW" ]; then
    echo "ERROR: workflow not found: $WORKFLOW" >&2
    exit 1
fi
if [ ! -f "$SCRIPT" ]; then
    echo "ERROR: script not found: $SCRIPT" >&2
    exit 1
fi

# 从 workflow YAML 中提取 VALIDATOR_BEGIN / VALIDATOR_END 之间的内容，
# 并去除 10 空格的缩进。
tmp_workflow_body="$(mktemp)"
tmp_script_body="$(mktemp)"
trap 'rm -f "$tmp_workflow_body" "$tmp_script_body"' EXIT

awk '
    /# >>> BEGIN_VALIDATOR_BODY/ { capturing=1; next }
    /# <<< END_VALIDATOR_BODY/   { capturing=0; next }
    capturing              { print }
' "$WORKFLOW" | sed 's/^          //' > "$tmp_workflow_body"

# 提取 standalone 脚本中 BEGIN/END_VALIDATOR_BODY 之间的内容
awk '
    />>> BEGIN_VALIDATOR_BODY/ { capturing=1; next }
    /<<< END_VALIDATOR_BODY/   { capturing=0; next }
    capturing                 { print }
' "$SCRIPT" > "$tmp_script_body"

if diff -u "$tmp_workflow_body" "$tmp_script_body" >/dev/null 2>&1; then
    echo "OK: inline validator 与 scripts/validate-payload.sh 一致"
    exit 0
fi

echo "ERROR: inline validator 与 scripts/validate-payload.sh 不一致" >&2
echo "--- diff ---" >&2
diff -u "$tmp_workflow_body" "$tmp_script_body" >&2 || true
exit 1
