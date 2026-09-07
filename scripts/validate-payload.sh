#!/usr/bin/env bash
# action-worker payload validator
#
# Pure input validation for repository_dispatch client_payload.
# No network, no secret access, no business logic.
#
# Usage:
#   validate-payload.sh <payload-json>
#
# Exit codes:
#   0  payload accepted
#   64 usage / invalid input
#   65 unsupported schema_version

set -Eeuo pipefail
IFS=$'\n\t'

if [ "$#" -ne 1 ]; then
    echo "::error::usage: validate-payload.sh <payload-json>" >&2
    exit 64
fi

PAYLOAD="$1"

if ! command -v jq >/dev/null 2>&1; then
    echo "::error::jq 不可用" >&2
    exit 1
fi

# >>> BEGIN_VALIDATOR_BODY
SUPPORTED_SCHEMA_VERSIONS=("1")

if ! printf '%s' "$PAYLOAD" | jq -e . >/dev/null 2>&1; then
    echo "::error::payload 不是合法 JSON" >&2
    exit 64
fi

schema_version=$(printf '%s' "$PAYLOAD" | jq -r '.schema_version // empty')
request_id=$(printf '%s' "$PAYLOAD"     | jq -r '.request_id     // empty')
project=$(printf '%s' "$PAYLOAD"        | jq -r '.project        // empty')
bootstrap_ref=$(printf '%s' "$PAYLOAD"  | jq -r '.bootstrap_ref  // empty')

if [ -z "$schema_version" ] || [ -z "$request_id" ] || [ -z "$project" ] || [ -z "$bootstrap_ref" ]; then
    echo "::error::payload 缺少必要字段 (schema_version / request_id / project / bootstrap_ref)" >&2
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
    echo "::error::不支持的 schema_version: ${schema_version}" >&2
    exit 65
fi

if ! [[ "$request_id" =~ ^[A-Za-z0-9_.-]{1,128}$ ]]; then
    echo "::error::非法 request_id" >&2
    exit 64
fi

if ! [[ "$project" =~ ^[A-Za-z0-9_.-]+$ ]]; then
    echo "::error::非法项目名称: ${project}" >&2
    exit 64
fi

if ! [[ "$bootstrap_ref" =~ ^[0-9a-fA-F]{40}$ ]]; then
    echo "::error::bootstrap_ref 必须为完整 40 位 Commit SHA" >&2
    exit 64
fi

unknown=$(printf '%s' "$PAYLOAD" | jq -r '
    ["schema_version","request_id","project","bootstrap_ref"] as $allowed |
    [ keys[] | select(. as $k | $allowed | index($k) | not) ]
    | join(",")
')
if [ -n "$unknown" ]; then
    echo "::error::payload 包含未知字段: ${unknown}" >&2
    exit 64
fi
# <<< END_VALIDATOR_BODY

exit 0
