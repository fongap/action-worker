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

if ! grep -qE 'toJSON\s*\(\s*secrets\s*\)' "$WORKFLOW"; then
    check_pass "不存在 toJSON(secrets)"
else
    check_fail "不存在 toJSON(secrets)" "发现 toJSON(secrets)"
fi

if grep -qF 'env: ${{ secrets }}' "$WORKFLOW"; then
    check_pass "Execute task 使用 env: \${{ secrets }}"
else
    check_fail "Execute task 使用 env: \${{ secrets }}" "未找到 env: \${{ secrets }}"
fi

if ! grep -qF 'GHOST_SECRET_POOL' "$WORKFLOW"; then
    check_pass "不存在 GHOST_SECRET_POOL"
else
    check_fail "不存在 GHOST_SECRET_POOL" "发现 GHOST_SECRET_POOL"
fi

if ! grep -qF 'PROJECT_SECRETS_JSON' "$WORKFLOW"; then
    check_pass "不存在 PROJECT_SECRETS_JSON"
else
    check_fail "不存在 PROJECT_SECRETS_JSON" "发现 PROJECT_SECRETS_JSON"
fi

if ! grep -qF 'PROJECT_SECRETS_BUNDLE' "$WORKFLOW"; then
    check_pass "不存在 PROJECT_SECRETS_BUNDLE"
else
    check_fail "不存在 PROJECT_SECRETS_BUNDLE" "发现 PROJECT_SECRETS_BUNDLE"
fi

business_secrets=0
for key in CF_ACCOUNT_ID_PRIMARY CF_PAGES_WRITE_TOKEN_PRIMARY OPENAI_API_KEY DATABASE_URL; do
    if grep -qF "$key" "$WORKFLOW"; then
        business_secrets=1
        break
    fi
done

if [ "$business_secrets" -eq 0 ]; then
    check_pass "action-worker 不包含任何业务 Secret 键名"
else
    check_fail "action-worker 不包含任何业务 Secret 键名" "发现业务 Secret 键名"
fi

if ! grep -qE 'environment:\s*$' "$WORKFLOW"; then
    check_pass "不存在动态 environment.name"
else
    check_fail "不存在动态 environment.name" "发现 environment:"
fi

if grep -qF 'Snapshot base environment' "$WORKFLOW"; then
    check_pass "存在 Snapshot base environment"
else
    check_fail "存在 Snapshot base environment" "未找到 Snapshot base environment"
fi

if grep -qF 'compgen -e' "$WORKFLOW"; then
    check_pass "基础环境快照只保存变量名"
else
    check_fail "基础环境快照只保存变量名" "未找到 compgen -e"
fi

if grep -qF 'action-worker-base-env.names' "$WORKFLOW"; then
    check_pass "cleanup 删除基础环境快照"
else
    check_fail "cleanup 删除基础环境快照" "未找到 action-worker-base-env.names"
fi

dangerous=0
if grep -qF 'set -x' "$WORKFLOW"; then dangerous=1; fi
if grep -qF 'printenv' "$WORKFLOW"; then dangerous=1; fi
if grep -qE '^\s*env\s*$' "$WORKFLOW"; then dangerous=1; fi

if [ "$dangerous" -eq 0 ]; then
    check_pass "不存在 set -x / printenv / shell 裸 env"
else
    check_fail "不存在 set -x / printenv / shell 裸 env" "发现危险命令"
fi

if grep -qF 'validate-payload.sh' "$WORKFLOW"; then
    check_pass "payload 继续由 validate-payload.sh 校验"
else
    check_fail "payload 继续由 validate-payload.sh 校验" "未找到 validate-payload.sh"
fi

printf '\nResult: passed=%s failed=%s\n' "$PASSED" "$FAILED"

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
