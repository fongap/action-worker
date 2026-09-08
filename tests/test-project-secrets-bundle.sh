#!/usr/bin/env bash

set -u

WORKFLOW=".github/workflows/task-handler.yml"

if [ ! -f "$WORKFLOW" ]; then
    echo "ERROR: $WORKFLOW not found." >&2
    exit 1
fi

PASSED=0
FAILED=0

check_pass() {
    local name="$1"
    printf 'PASS  %s\n' "$name"
    PASSED=$((PASSED + 1))
}

check_fail() {
    local name="$1"
    local reason="$2"
    printf 'FAIL  %s（%s）\n' "$name" "$reason" >&2
    FAILED=$((FAILED + 1))
}

if grep -qF 'toJSON(secrets)' "$WORKFLOW"; then
    check_pass "workflow 使用 toJSON(secrets)"
else
    check_fail "workflow 使用 toJSON(secrets)" "未找到 toJSON(secrets)"
fi

if grep -qF 'PROJECT_SECRETS_BUNDLE: ${{ toJSON(secrets) }}' "$WORKFLOW"; then
    check_pass "workflow 注入 PROJECT_SECRETS_BUNDLE"
else
    check_fail "workflow 注入 PROJECT_SECRETS_BUNDLE" "env 中未定义 PROJECT_SECRETS_BUNDLE"
fi

if grep -qF 'export PROJECT_SECRETS_BUNDLE' "$WORKFLOW"; then
    check_pass "workflow export PROJECT_SECRETS_BUNDLE"
else
    check_fail "workflow export PROJECT_SECRETS_BUNDLE" "未找到 export PROJECT_SECRETS_BUNDLE"
fi

if grep -qF 'unset PROJECT_SECRETS_BUNDLE' "$WORKFLOW"; then
    check_pass "cleanup unset PROJECT_SECRETS_BUNDLE"
else
    check_fail "cleanup unset PROJECT_SECRETS_BUNDLE" "未找到 unset PROJECT_SECRETS_BUNDLE"
fi

if ! grep -qE '(echo|printf)\s.*\$PROJECT_SECRETS_BUNDLE' "$WORKFLOW"; then
    check_pass "workflow 不直接输出 PROJECT_SECRETS_BUNDLE"
else
    check_fail "workflow 不直接输出 PROJECT_SECRETS_BUNDLE" "发现 echo/printf 输出 \$PROJECT_SECRETS_BUNDLE"
fi

if grep -qF 'set -x' "$WORKFLOW"; then
    check_fail "workflow 不启用 set -x" "发现 set -x"
else
    check_pass "workflow 不启用 set -x"
fi

printf '\nResult: passed=%s failed=%s\n' "$PASSED" "$FAILED"

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
