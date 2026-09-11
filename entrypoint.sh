#!/usr/bin/env bash
set -euo pipefail

# Entry point for the claude-code-claudish-happy image.
#
# Usage:
#   docker run ... claude              # plain Claude Code (default)
#   docker run ... claudish [args...]  # Claude Code via Claudish (any model)
#   docker run ... happy claude        # Claude Code wrapped by Happy (mobile/web control)
#   docker run ... happy codex         # Codex wrapped by Happy
#   docker run ... claudish-happy [claudish args...]
#                                       # Claudish's model proxy AND Happy's
#                                       # mobile/web control, both in front of
#                                       # the same Claude Code session
#   docker run ... bash                # drop into a shell with all three CLIs on PATH
#
# Before exec'ing the requested CLI, this checks that the environment
# variables that CLI needs were actually supplied (e.g. via `environment:`
# in docker-compose.yml or `docker run -e ...`), and fails fast with a clear
# message instead of letting the CLI hang on a login prompt or die deep in
# its own startup code.
#
# For `claudish` / `claudish-happy`, it also registers any custom
# OpenAI-compatible / Anthropic-compatible endpoint given via
# CUSTOM_OPENAI_BASE_URL / CUSTOM_ANTHROPIC_BASE_URL (+ optional
# *_API_KEY) as Claudish "customEndpoints" named custom-openai /
# custom-anthropic - see configure-claudish-endpoints.sh and .env.example.

PLACEHOLDER="sk-ant-api03-placeholder"

die() {
    echo "" >&2
    echo "error: $1" >&2
    echo "" >&2
    exit 1
}

is_set() {
    # true if the named env var is set and non-empty
    local name="$1"
    [ -n "${!name:-}" ]
}

require_one_of() {
    # require_one_of "PURPOSE" VAR1 VAR2 ...
    local purpose="$1"; shift
    for var in "$@"; do
        if is_set "$var"; then
            return 0
        fi
    done
    die "$purpose requires one of the following environment variables to be set: $*
Set it in your docker-compose.yml 'environment:' block (or -e on 'docker run'). See .env.example."
}

require_anthropic_key() {
    if ! is_set ANTHROPIC_API_KEY || [ "${ANTHROPIC_API_KEY}" = "${PLACEHOLDER}" ]; then
        die "claude requires a real ANTHROPIC_API_KEY (the image only ships a placeholder to suppress the login dialog when using claudish).
Set ANTHROPIC_API_KEY in your docker-compose.yml 'environment:' block. See .env.example."
    fi
}

case "${1:-claude}" in
    claude)
        require_anthropic_key
        ;;
    claudish)
        configure-claudish-endpoints
        require_one_of "claudish" OPENROUTER_API_KEY GEMINI_API_KEY OPENAI_API_KEY OLLAMA_HOST \
            CUSTOM_OPENAI_BASE_URL CUSTOM_ANTHROPIC_BASE_URL
        ;;
    claudish-happy)
        configure-claudish-endpoints
        require_one_of "claudish-happy" OPENROUTER_API_KEY GEMINI_API_KEY OPENAI_API_KEY OLLAMA_HOST \
            CUSTOM_OPENAI_BASE_URL CUSTOM_ANTHROPIC_BASE_URL
        # claudish resolves the "claude" binary it launches via $CLAUDE_PATH
        # (falling back to a normal PATH lookup); point it at a wrapper that
        # runs `happy claude` instead of Claude Code directly. claudish's env
        # setup (ANTHROPIC_BASE_URL, the placeholder ANTHROPIC_API_KEY, its
        # --settings overlay, etc.) is inherited by that wrapper and, in
        # turn, by the real Claude Code process happy spawns underneath it -
        # so the model proxy and Happy's remote control both attach to the
        # same session.
        export CLAUDE_PATH=/usr/local/bin/claude-via-happy
        shift
        set -- claudish "$@"
        ;;
    happy)
        case "${2:-}" in
            codex)
                require_one_of "happy codex" OPENAI_API_KEY
                ;;
            claude|*)
                require_anthropic_key
                ;;
        esac
        ;;
    *)
        # Anything else (bash, sh, a custom command, ...) - run as-is,
        # no env requirements enforced.
        ;;
esac

exec "$@"
