#!/usr/bin/env bash

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
RESOLVER="$SCRIPT_DIR/../scripts/resolve-declarations.sh"

PASSED=0
FAILED=0

if [ ! -f "$RESOLVER" ]; then
    echo "ERROR: 找不到声明解析脚本：$RESOLVER" >&2
    exit 1
fi

TMPDIR_TEST="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_TEST"' EXIT

write_file() {
    printf '%s\n' "$1" > "$2"
}

check() {
    local name="$1"
    local secrets_content="$2"
    local vars_content="$3"
    local secrets_json="$4"
    local vars_json="$5"
    local expected="$6"

    local sf="$TMPDIR_TEST/secrets.required"
    local vf="$TMPDIR_TEST/env.variables"

    write_file "$secrets_content" "$sf"
    write_file "$vars_content" "$vf"

    local actual=0
    local output
    output=$(AVAILABLE_SECRETS_JSON="$secrets_json" \
             AVAILABLE_VARS_JSON="$vars_json" \
             bash "$RESOLVER" "$sf" "$vf" 2>&1) || actual=$?

    if [ "$actual" -eq "$expected" ]; then
        printf 'PASS  %s\n' "$name"
        PASSED=$((PASSED + 1))
    else
        printf 'FAIL  %s（期望=%s，实际=%s）\n' \
            "$name" "$expected" "$actual" >&2
        printf '      输出: %s\n' "$output" >&2
        FAILED=$((FAILED + 1))
    fi
}

# --- 合法 .secrets.required ---
check "合法 .secrets.required" \
    'CF_ACCOUNT_ID_PRIMARY
CF_PAGES_WRITE_TOKEN_PRIMARY' \
    '' \
    '{"CF_ACCOUNT_ID_PRIMARY":"val1","CF_PAGES_WRITE_TOKEN_PRIMARY":"val2"}' \
    '{}' \
    0

# --- Secret 缺失 ---
check "缺少项目 Secret" \
    'CF_ACCOUNT_ID_PRIMARY
CF_PAGES_WRITE_TOKEN_PRIMARY' \
    '' \
    '{"CF_ACCOUNT_ID_PRIMARY":"val1"}' \
    '{}' \
    1

# --- Secret 重复 ---
check "Secret 重复声明" \
    'CF_ACCOUNT_ID_PRIMARY
CF_ACCOUNT_ID_PRIMARY' \
    '' \
    '{}' \
    '{}' \
    1

# --- Secret 非法名称 ---
check "Secret 名称非法（小写）" \
    'cf_account_id' \
    '' \
    '{}' \
    '{}' \
    1

check "Secret 名称非法（数字开头）" \
    '1SECRET' \
    '' \
    '{}' \
    '{}' \
    1

# --- 多余 Secret 被拒绝 ---
check "多余 Secret 被拒绝" \
    'CF_ACCOUNT_ID_PRIMARY' \
    '' \
    '{"CF_ACCOUNT_ID_PRIMARY":"val1","OLD_TOKEN":"secret","UNUSED_ADMIN_TOKEN":"secret2"}' \
    '{}' \
    1

# --- 合法 KEY=value ---
check "合法 KEY=value" \
    '' \
    'NODE_ENV=production
API_VERSION=v2' \
    '{}' \
    '{"NODE_ENV":"production","API_VERSION":"v2"}' \
    0

# --- 合法裸 KEY ---
check "合法裸 KEY" \
    '' \
    'NODE_ENV
API_VERSION' \
    '{}' \
    '{"NODE_ENV":"production","API_VERSION":"v2"}' \
    0

# --- 裸 KEY 缺失 ---
check "裸 KEY 缺失" \
    '' \
    'NODE_ENV
API_VERSION' \
    '{}' \
    '{"NODE_ENV":"production"}' \
    1

# --- Variable / Secret 同名冲突 ---
check "Variable/Secret 同名冲突" \
    'FOO' \
    'FOO' \
    '{"FOO":"secret_val"}' \
    '{"FOO":"var_val"}' \
    1

# --- .env.variables 重复声明 ---
check ".env.variables 重复声明" \
    '' \
    'FOO
FOO' \
    '{}' \
    '{}' \
    1

# --- 注释和空行 ---
check "注释和空行被忽略" \
    '# This is a comment

CF_ACCOUNT_ID_PRIMARY
# Another comment
CF_PAGES_WRITE_TOKEN_PRIMARY
' \
    '# Comment
NODE_ENV=production

# Another
API_VERSION
' \
    '{"CF_ACCOUNT_ID_PRIMARY":"v1","CF_PAGES_WRITE_TOKEN_PRIMARY":"v2"}' \
    '{"NODE_ENV":"production","API_VERSION":"v2"}' \
    0

# --- .secrets.required 空文件 ---
check ".secrets.required 空文件" \
    '' \
    '' \
    '{}' \
    '{}' \
    0

# --- .env.variables 空文件 ---
check ".env.variables 空文件" \
    '' \
    '' \
    '{}' \
    '{}' \
    0

# --- 混合 KEY=value 和裸 KEY ---
check "混合 KEY=value 和裸 KEY" \
    '' \
    'NODE_ENV=production
DEBUG
API_KEY=key123' \
    '{}' \
    '{"NODE_ENV":"production","DEBUG":"true","API_KEY":"key123"}' \
    0

# --- Infrastructure secrets 不在白名单中 ---
check "Infrastructure secrets 不触发多余检查" \
    'CF_ACCOUNT_ID_PRIMARY' \
    '' \
    '{"CF_ACCOUNT_ID_PRIMARY":"val1","GITHUB_TOKEN":"gh_token","GH_EXECUTION_REPO_PAT":"pat_val"}' \
    '{}' \
    0

printf '\nResult: passed=%s failed=%s\n' "$PASSED" "$FAILED"

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
