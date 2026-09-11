#!/usr/bin/env bash
set -euo pipefail

# Registers custom OpenAI-compatible / Anthropic-compatible endpoints with
# Claudish, from plain env vars, so users don't have to hand-write
# ~/.claudish/config.json.
#
# Claudish's own "customEndpoints" feature (see its docs/settings-reference.md,
# section 7.5) reads a map of named endpoints from ~/.claudish/config.json:
# each is { kind: "simple", url, format: "openai"|"anthropic", apiKey, ... }
# and becomes usable as `claudish --model <name>@<model>`. This script builds
# that map from:
#
#   CUSTOM_OPENAI_BASE_URL     / CUSTOM_OPENAI_API_KEY     -> "custom-openai"   (format: openai)
#   CUSTOM_ANTHROPIC_BASE_URL  / CUSTOM_ANTHROPIC_API_KEY   -> "custom-anthropic" (format: anthropic)
#
# Either pair is optional and independent; set only the one(s) you need. If
# the *_API_KEY var is empty, the endpoint is registered with authScheme:
# "none" (for a local/trusted gateway that needs no auth header) instead of
# sending a literal empty/placeholder key.
#
# The apiKey is written to config.json as a "${VAR}" reference, not the
# literal secret - Claudish expands it from its own process env at startup
# (docs section on environment variable expansion), so the actual key value
# never has to be written to disk.
#
# Safe to run every container start: it merges into (rather than replaces)
# any existing ~/.claudish/config.json, so it won't clobber settings you or
# Claudish itself have written there (e.g. in a persisted ~/.claudish volume).

CONFIG_DIR="${HOME}/.claudish"
CONFIG_FILE="${CONFIG_DIR}/config.json"

build_endpoint() {
    # build_endpoint <format> <url-var-name> <key-var-name>
    local format="$1" url_var="$2" key_var="$3"
    local url="${!url_var:-}"
    [ -z "$url" ] && return 1

    local key_var_ref="\${${key_var}}"
    if [ -n "${!key_var:-}" ]; then
        jq -n --arg url "$url" --arg format "$format" --arg apiKeyRef "$key_var_ref" \
            '{kind: "simple", url: $url, format: $format, apiKey: $apiKeyRef}'
    else
        jq -n --arg url "$url" --arg format "$format" \
            '{kind: "simple", url: $url, format: $format, authScheme: "none"}'
    fi
}

endpoints_json='{}'

if entry=$(build_endpoint openai CUSTOM_OPENAI_BASE_URL CUSTOM_OPENAI_API_KEY); then
    endpoints_json=$(jq --argjson e "$entry" '. + {"custom-openai": $e}' <<<"$endpoints_json")
fi

if entry=$(build_endpoint anthropic CUSTOM_ANTHROPIC_BASE_URL CUSTOM_ANTHROPIC_API_KEY); then
    endpoints_json=$(jq --argjson e "$entry" '. + {"custom-anthropic": $e}' <<<"$endpoints_json")
fi

[ "$endpoints_json" = '{}' ] && exit 0

mkdir -p "$CONFIG_DIR"
existing='{}'
[ -f "$CONFIG_FILE" ] && existing=$(cat "$CONFIG_FILE")

jq --argjson new "$endpoints_json" \
    '.customEndpoints = ((.customEndpoints // {}) + $new)' \
    <<<"$existing" > "${CONFIG_FILE}.tmp"
mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
