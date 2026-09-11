#!/usr/bin/env bash
set -euo pipefail

# Entry point for the claude-code-claudish-happy image.
#
# Usage:
#   docker run ... claude              # plain Claude Code (default)
#   docker run ... claudish [args...]  # Claude Code via Claudish (any model)
#   docker run ... happy claude        # Claude Code wrapped by Happy (mobile/web control)
#   docker run ... happy codex         # Codex wrapped by Happy
#   docker run ... bash                # drop into a shell with all three CLIs on PATH
#
# Any command/args passed to `docker run` are exec'd directly.
exec "$@"
