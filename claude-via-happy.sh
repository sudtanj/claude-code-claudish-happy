#!/usr/bin/env bash
set -euo pipefail

# Stand-in "claude" binary for Claudish to launch (see $CLAUDE_PATH in the
# `claudish-happy` entrypoint command).
#
# Claudish spawns whatever $CLAUDE_PATH points to with Claude-Code-shaped
# CLI args, and with ANTHROPIC_BASE_URL / a placeholder ANTHROPIC_API_KEY
# (pointing at its local model proxy) already set in the child's
# environment. Instead of running the real `claude` binary directly, this
# hands those same args to `happy claude`, which spawns the real Claude
# Code process itself, inheriting the full parent environment -
# Claudish's proxy env included. Net effect: Happy's mobile/web control
# wraps a Claude Code session that is, in turn, routed through Claudish.
exec happy claude "$@"
