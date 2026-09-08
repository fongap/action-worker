#!/usr/bin/env bash
# payload validator tests

set -u

TESTS_PASSED=0
TESTS_FAILED=0

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VALIDATOR="$SCRIPT_DIR/../scripts/validate-payload.sh"

if [ ! -x "$VALIDATOR" ]; then
    echo "ERROR: validator 不存在或不可执行: $VALIDATOR" >&2
    exit 1
fi

GOOD_SHA="0123456789abcdef0123456789abcdef01234567"

check() {
    local name="$1"
    local payload="$2"
    local expected_rc="$3"
    local actual_rc=0

    "$VALIDATOR" "$payload" >/dev/null 2>&1 || actual_rc=$?

    if [ "$actual_rc" -eq "$expected_rc" ]; then
        echo "  PASS  $name (rc=$actual_rc)"
        TESTS_PASSED=$((TESTS_PASSED + 1))
    else
        echo "  FAIL  $name (expected=$expected_rc actual=$actual_rc)"
        TESTS_FAILED=$((TESTS_FAILED + 1))
    fi
}

echo "[group] 合法 Payload"

check "合法 payload" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    0

echo "[group] 非法 project"

check "包含斜杠" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"foo/bar\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    64

check "包含 .." \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"../../etc\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    64

check "包含 \$" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"foo\$bar\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    64

check "包含空格" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"foo bar\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    64

check "空字符串" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    64

echo "[group] 非法 bootstrap_ref"

check "main" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"main\"}" \
    64

check "短 SHA" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"abc123\"}" \
    64

check "39 位" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"0123456789abcdef0123456789abcdef0123456\"}" \
    64

check "41 位" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"0123456789abcdef0123456789abcdef012345678\"}" \
    64

check "非 hex" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"ZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZZ\"}" \
    64

check "缺失" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\"}" \
    64

echo "[group] 缺少必要字段"

check "空对象" \
    "{}" \
    64

check "缺 request_id" \
    "{\"schema_version\":\"1\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    64

check "缺 schema_version" \
    "{\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    64

check "非 JSON" \
    "not json" \
    64

echo "[group] 不支持的 schema_version"

check "schema=2" \
    "{\"schema_version\":\"2\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    65

check "schema=0" \
    "{\"schema_version\":\"0\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    65

check "schema=空" \
    "{\"schema_version\":\"\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    64

echo "[group] 未知字段"

check "含 command 字段" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"$GOOD_SHA\",\"command\":\"rm -rf /\"}" \
    64

check "含 secret 字段" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"$GOOD_SHA\",\"secret\":\"GH_ARTIFACT_REPO_PAT=x\"}" \
    64

check "含 script 字段" \
    "{\"schema_version\":\"1\",\"request_id\":\"req-001\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"$GOOD_SHA\",\"script\":\"bash -i\"}" \
    64

echo "[group] 非法 request_id"

check "超长" \
    "{\"schema_version\":\"1\",\"request_id\":\"$(printf 'a%.0s' {1..200})\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    64

check "包含斜杠" \
    "{\"schema_version\":\"1\",\"request_id\":\"a/b\",\"project\":\"FongapBlog\",\"bootstrap_ref\":\"$GOOD_SHA\"}" \
    64

echo
echo "==== Result: passed=$TESTS_PASSED failed=$TESTS_FAILED ===="

if [ "$TESTS_FAILED" -ne 0 ]; then
    exit 1
fi