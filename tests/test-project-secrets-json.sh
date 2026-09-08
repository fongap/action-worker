#!/usr/bin/env bash

set -u

if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq is required to run this test." >&2
    exit 1
fi

PASSED=0
FAILED=0

check() {
    local name="$1"
    local input="$2"
    local expected_rc="$3"
    local expected_output="${4:-}"
    local actual_rc=0
    local actual_output=""

    unset PROJECT_SECRETS_JSON 2>/dev/null || true

    if [ "$input" = "__UNSET__" ]; then
        actual_output=$(
            if [ -z "${PROJECT_SECRETS_JSON:-}" ]; then
                PROJECT_SECRETS_JSON='{}'
            fi

            if ! printf '%s' "$PROJECT_SECRETS_JSON" |
                jq -e 'type == "object"' >/dev/null 2>&1; then
                echo "::error::PROJECT_SECRETS_JSON 不是合法 JSON 对象。" >&2
                exit 1
            fi

            printf '%s' "$PROJECT_SECRETS_JSON" | jq -c '.'
        ) || actual_rc=$?
    else
        PROJECT_SECRETS_JSON="$input"
        actual_output=$(
            if [ -z "${PROJECT_SECRETS_JSON:-}" ]; then
                PROJECT_SECRETS_JSON='{}'
            fi

            if ! printf '%s' "$PROJECT_SECRETS_JSON" |
                jq -e 'type == "object"' >/dev/null 2>&1; then
                echo "::error::PROJECT_SECRETS_JSON 不是合法 JSON 对象。" >&2
                exit 1
            fi

            printf '%s' "$PROJECT_SECRETS_JSON" | jq -c '.'
        ) || actual_rc=$?
    fi

    if [ "$actual_rc" -ne "$expected_rc" ]; then
        printf 'FAIL  %s（期望 rc=%s，实际 rc=%s）\n' \
            "$name" "$expected_rc" "$actual_rc" >&2
        FAILED=$((FAILED + 1))
        return
    fi

    if [ -n "$expected_output" ] && [ "$actual_output" != "$expected_output" ]; then
        printf 'FAIL  %s（期望输出=%s，实际输出=%s）\n' \
            "$name" "$expected_output" "$actual_output" >&2
        FAILED=$((FAILED + 1))
        return
    fi

    printf 'PASS  %s\n' "$name"
    PASSED=$((PASSED + 1))
}

check_log_safe() {
    local name="$1"
    local input="$2"
    local log_file
    log_file=$(mktemp)

    unset PROJECT_SECRETS_JSON 2>/dev/null || true

    if [ "$input" = "__UNSET__" ]; then
        {
            if [ -z "${PROJECT_SECRETS_JSON:-}" ]; then
                PROJECT_SECRETS_JSON='{}'
            fi

            if ! printf '%s' "$PROJECT_SECRETS_JSON" |
                jq -e 'type == "object"' >/dev/null 2>&1; then
                echo "::error::PROJECT_SECRETS_JSON 不是合法 JSON 对象。" >&2
                exit 1
            fi

            printf '%s' "$PROJECT_SECRETS_JSON" | jq -c '.'
        } > "$log_file" 2>&1
    else
        PROJECT_SECRETS_JSON="$input"
        {
            if [ -z "${PROJECT_SECRETS_JSON:-}" ]; then
                PROJECT_SECRETS_JSON='{}'
            fi

            if ! printf '%s' "$PROJECT_SECRETS_JSON" |
                jq -e 'type == "object"' >/dev/null 2>&1; then
                echo "::error::PROJECT_SECRETS_JSON 不是合法 JSON 对象。" >&2
                exit 1
            fi

            printf '%s' "$PROJECT_SECRETS_JSON" | jq -c '.'
        } > "$log_file" 2>&1
    fi

    local leaked=0
    if [ "$input" != "__UNSET__" ]; then
        if grep -qF "$input" "$log_file" 2>/dev/null; then
            leaked=1
        fi
    fi

    rm -f "$log_file"

    if [ "$leaked" -eq 1 ]; then
        printf 'FAIL  %s（JSON 内容泄露到日志）\n' "$name" >&2
        FAILED=$((FAILED + 1))
    else
        printf 'PASS  %s\n' "$name"
        PASSED=$((PASSED + 1))
    fi
}

check "未设置 → 默认 {}" \
    "__UNSET__" \
    0 \
    "{}"

check "空对象 {} → 成功" \
    '{}' \
    0 \
    "{}"

check "正常 JSON 对象 → 内容不变" \
    '{"CF_ACCOUNT_ID":"abc123","CF_TOKEN":"secret456"}' \
    0 \
    '{"CF_ACCOUNT_ID":"abc123","CF_TOKEN":"secret456"}'

check "包含多个 Secret 的 JSON → 成功" \
    '{"KEY1":"val1","KEY2":"val2","KEY3":"val3"}' \
    0 \
    '{"KEY1":"val1","KEY2":"val2","KEY3":"val3"}'

check "非 JSON → 失败" \
    'not json' \
    1

check "JSON array → 失败" \
    '["item1","item2"]' \
    1

check "JSON string → 失败" \
    '"just a string"' \
    1

check "JSON number → 失败" \
    '12345' \
    1

check "JSON null → 失败" \
    'null' \
    1

check_log_safe "日志中不泄露 JSON 内容" \
    '{"SECRET_KEY":"super_secret_value_12345"}'

printf '\nResult: passed=%s failed=%s\n' "$PASSED" "$FAILED"

if [ "$FAILED" -ne 0 ]; then
    exit 1
fi
