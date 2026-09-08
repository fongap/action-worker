#!/usr/bin/env bash

set -Eeuo pipefail
IFS=$'\n\t'

if [ "$#" -ne 2 ]; then
    echo "用法: resolve-declarations.sh <.secrets.required> <.env.variables>" >&2
    exit 1
fi

SECRETS_FILE="$1"
VARS_FILE="$2"

SECRET_NAMES=()
VARIABLE_KEYS=()

parse_secrets_required() {
    local line
    local name
    declare -A seen

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%$'\r'}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        [ -z "$line" ] && continue
        [[ "$line" == \#* ]] && continue

        name="$line"

        if ! [[ "$name" =~ ^[A-Z_][A-Z0-9_]*$ ]]; then
            echo "::error::.secrets.required 格式错误：'${name}' 名称非法。" >&2
            exit 1
        fi

        if [ -v "seen[$name]" ]; then
            echo "::error::.secrets.required 格式错误：'${name}' 重复声明。" >&2
            exit 1
        fi
        seen[$name]=1

        SECRET_NAMES+=("$name")
    done < "$SECRETS_FILE"
}

parse_env_variables() {
    local line key value
    declare -A seen

    while IFS= read -r line || [ -n "$line" ]; do
        line="${line%%$'\r'}"
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        [ -z "$line" ] && continue
        [[ "$line" == \#* ]] && continue

        if [[ "$line" == *=* ]]; then
            key="${line%%=*}"
            value="${line#*=}"
            continue
        fi

        key="$line"

        if [ -v "seen[$key]" ]; then
            echo "::error::.env.variables 格式错误：'${key}' 重复声明。" >&2
            exit 1
        fi
        seen[$key]=1

        VARIABLE_KEYS+=("$key")
    done < "$VARS_FILE"
}

check_conflicts() {
    local secret_name var_key
    for secret_name in "${SECRET_NAMES[@]}"; do
        for var_key in "${VARIABLE_KEYS[@]}"; do
            if [ "$secret_name" = "$var_key" ]; then
                echo "::error::${secret_name} 同时声明为 Variable 和 Secret" >&2
                exit 1
            fi
        done
    done
}

extract_secrets() {
    [ ${#SECRET_NAMES[@]} -eq 0 ] && return 0

    local available_json="$1"
    local missing=()
    local name value

    for name in "${SECRET_NAMES[@]}"; do
        value=$(printf '%s' "$available_json" | jq -r --arg k "$name" '.[$k] // empty')
        if [ -z "$value" ]; then
            missing+=("$name")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "::error::缺少项目 Secret: ${missing[*]}" >&2
        exit 1
    fi

    for name in "${SECRET_NAMES[@]}"; do
        value=$(printf '%s' "$available_json" | jq -r --arg k "$name" '.[$k]')
        export "$name=$value"
        printf '::add-mask::%s\n' "$value"
        printf '%s\n' "$name"
    done
}

check_extra_secrets() {
    local available_json="$1"
    local infrastructure="^(GITHUB_TOKEN|GH_EXECUTION_REPO_PAT)$"
    local extra=()
    local key

    while IFS= read -r key; do
        [ -z "$key" ] && continue
        if [[ "$key" =~ $infrastructure ]]; then
            continue
        fi
        local found=0
        local name
        for name in "${SECRET_NAMES[@]}"; do
            if [ "$name" = "$key" ]; then
                found=1
                break
            fi
        done
        if [ "$found" -eq 0 ]; then
            extra+=("$key")
        fi
    done < <(printf '%s' "$available_json" | jq -r 'keys[]')

    if [ ${#extra[@]} -gt 0 ]; then
        echo "::error::Environment 存在未声明 Secret:" >&2
        for key in "${extra[@]}"; do
            printf '  %s\n' "$key" >&2
        done
        exit 1
    fi
}

extract_variables() {
    [ ${#VARIABLE_KEYS[@]} -eq 0 ] && return 0

    local available_json="$1"
    local missing=()
    local key value

    for key in "${VARIABLE_KEYS[@]}"; do
        value=$(printf '%s' "$available_json" | jq -r --arg k "$key" '.[$k] // empty')
        if [ -z "$value" ]; then
            missing+=("$key")
        fi
    done

    if [ ${#missing[@]} -gt 0 ]; then
        echo "::error::缺少项目 Variable: ${missing[*]}" >&2
        exit 1
    fi

    for key in "${VARIABLE_KEYS[@]}"; do
        value=$(printf '%s' "$available_json" | jq -r --arg k "$key" '.[$k]')
        export "$key=$value"
        printf '%s\n' "$key"
    done
}

cleanup() {
    unset AVAILABLE_SECRETS_JSON 2>/dev/null || true
    unset AVAILABLE_VARS_JSON 2>/dev/null || true
}

trap cleanup EXIT

available_secrets="${AVAILABLE_SECRETS_JSON:-{}}"
available_vars="${AVAILABLE_VARS_JSON:-{}}"

parse_secrets_required
parse_env_variables
check_conflicts
check_extra_secrets "$available_secrets"
extract_secrets "$available_secrets"
extract_variables "$available_vars"
