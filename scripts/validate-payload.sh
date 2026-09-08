#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

if [ "$#" -ne 1 ]; then
    echo "::error::参数错误：请传入 repository_dispatch 的 client_payload JSON。" >&2
    exit 64
fi

PAYLOAD="$1"

if ! command -v jq >/dev/null 2>&1; then
    echo "::error::运行环境缺少 jq，无法校验任务参数。" >&2
    exit 1
fi

SUPPORTED_SCHEMA_VERSIONS=("1")

if ! printf '%s' "$PAYLOAD" | jq -e . >/dev/null 2>&1; then
    echo "::error::请求数据格式错误：payload 不是合法 JSON。" >&2
    exit 64
fi

if ! printf '%s' "$PAYLOAD" | jq -e '
    type == "object" and
    (.schema_version | type == "string") and
    (.request_id | type == "string") and
    (.project | type == "string") and
    (.bootstrap_ref | type == "string")
' >/dev/null 2>&1; then
    echo "::error::请求字段类型错误：schema_version、request_id、project、bootstrap_ref 均应为字符串。" >&2
    exit 64
fi

schema_version=$(printf '%s' "$PAYLOAD" | jq -r '.schema_version // empty')
request_id=$(printf '%s' "$PAYLOAD"     | jq -r '.request_id     // empty')
project=$(printf '%s' "$PAYLOAD"        | jq -r '.project        // empty')
bootstrap_ref=$(printf '%s' "$PAYLOAD"  | jq -r '.bootstrap_ref  // empty')

if [ -z "$schema_version" ] || [ -z "$request_id" ] || [ -z "$project" ] || [ -z "$bootstrap_ref" ]; then
    echo "::error::请求数据不完整：缺少 schema_version、request_id、project 或 bootstrap_ref。" >&2
    exit 64
fi

supported=0
for v in "${SUPPORTED_SCHEMA_VERSIONS[@]}"; do
    if [ "$v" = "$schema_version" ]; then
        supported=1
        break
    fi
done

if [ "$supported" -ne 1 ]; then
    echo "::error::Schema 版本不支持：收到 ${schema_version}，当前支持 ${SUPPORTED_SCHEMA_VERSIONS[*]}。" >&2
    exit 65
fi

if ! [[ "$request_id" =~ ^[A-Za-z0-9_.-]{1,128}$ ]]; then
    echo "::error::request_id 格式错误：仅允许字母、数字、点、下划线和横线，最长 128 个字符。" >&2
    exit 64
fi

if ! [[ "$project" =~ ^[A-Za-z0-9][A-Za-z0-9_.-]{0,63}$ ]]; then
    echo "::error::项目名称格式错误：必须以字母或数字开头，仅允许字母、数字、点、下划线和横线，最长 64 个字符。" >&2
    exit 64
fi

if ! [[ "$bootstrap_ref" =~ ^[0-9a-fA-F]{40}$ ]]; then
    echo "::error::bootstrap_ref 格式错误：必须使用完整的 40 位 Commit SHA。" >&2
    exit 64
fi

unknown=$(printf '%s' "$PAYLOAD" | jq -r '
    ["schema_version","request_id","project","bootstrap_ref"] as $allowed |
    [ keys[] | select(. as $k | $allowed | index($k) | not) ]
    | join(",")
')

if [ -n "$unknown" ]; then
    echo "::error::请求包含不支持的字段：${unknown}。允许字段仅为 schema_version、request_id、project、bootstrap_ref。" >&2
    exit 64
fi

exit 0
