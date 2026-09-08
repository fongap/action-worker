#!/usr/bin/env bash

set -u

WORKFLOW=".github/workflows/task-handler.yml"
VALIDATE_SCRIPT="scripts/validate-payload.sh"

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

if grep -qF 'GHOST_SECRET_POOL: ${{ toJSON(secrets) }}' "$WORKFLOW"; then
    check_pass "workflow 使用 GHOST_SECRET_POOL"
else
    check_fail "workflow 使用 GHOST_SECRET_POOL" "未找到 GHOST_SECRET_POOL: \${{ toJSON(secrets) }}"
fi

if grep -qF 'toJSON(secrets)' "$WORKFLOW"; then
    check_pass "GHOST_SECRET_POOL 来源为 secrets context"
else
    check_fail "GHOST_SECRET_POOL 来源为 secrets context" "未找到 toJSON(secrets)"
fi

business_secrets=0
for key in CF_ACCOUNT_ID_PRIMARY CF_PAGES_WRITE_TOKEN_PRIMARY OPENAI_API_KEY DATABASE_URL; do
    if grep -qF "$key" "$WORKFLOW"; then
        business_secrets=1
        break
    fi
done

if [ "$business_secrets" -eq 0 ]; then
    check_pass "action-worker 不包含业务 Secret 具体键名"
else
    check_fail "action-worker 不包含业务 Secret 具体键名" "发现业务 Secret 键名"
fi

if ! grep -qE 'environment:\s*\n\s*name:' "$WORKFLOW"; then
    check_pass "不存在动态 environment.name = project"
else
    check_fail "不存在动态 environment.name = project" "发现 environment.name"
fi

if grep -qF 'unset GHOST_SECRET_POOL' "$WORKFLOW"; then
    check_pass "cleanup 清理 GHOST_SECRET_POOL"
else
    check_fail "cleanup 清理 GHOST_SECRET_POOL" "未找到 unset GHOST_SECRET_POOL"
fi

if ! grep -qE '(echo|printf)\s.*\$GHOST_SECRET_POOL' "$WORKFLOW"; then
    check_pass "workflow 不输出 GHOST_SECRET_POOL"
else
    check_fail "workflow 不输出 GHOST_SECRET_POOL" "发现 echo/printf 输出 \$GHOST_SECRET_POOL"
fi

dangerous=0
if grep -qF 'set -x' "$WORKFLOW"; then dangerous=1; fi
if grep -qF 'printenv' "$WORKFLOW"; then dangerous=1; fi
if echo "$WORKFLOW" | grep -qE '^\s*env\s*$'; then dangerous=1; fi

if [ "$dangerous" -eq 0 ]; then
    check_pass "不存在 set -x / printenv / 裸 env"
else
    check_fail "不存在 set -x / printenv / 裸 env" "发现危险命令"
fi

if grep -qF 'validate-payload.sh' "$WORKFLOW"; then
    check_pass "payload 仍通过 validate-payload.sh 校验"
else
    check_fail "payload 仍通过 validate-payload.sh 校验" "未找到 validate-payload.sh"
fi

if grep -qE '[0-9a-f]{40}' "$WORKFLOW"; then
    check_pass "bootstrap_ref 仍要求固定 SHA"
else
    check_fail "bootstrap_ref 仍要求固定 SHA" "未找到 40 位 SHA"
fi

printf '\nResult: passed=%s failed=%s\n' "$PASSED" "$FAILED"

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
