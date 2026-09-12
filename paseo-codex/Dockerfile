# syntax=docker/dockerfile:1

# Paseo (https://github.com/getpaseo/paseo) + Codex CLI.
#
# Paseo's own published image ships NO agent CLIs by default - its docs
# (docs/docker.md, "Installing Agents") document exactly this pattern:
# FROM the base image, USER root, npm install -g whichever agent CLIs you
# want, and leave the child image's user as root (Paseo's own entrypoint
# is the thing that drops privileges to the non-root `paseo` user, for
# both the daemon itself and any agent it launches).
#
# On top of that, this adds this repo's own Codex BYOK support: point
# Codex at any OpenAI-Responses-API-compatible endpoint via
# CODEX_BASE_URL / CODEX_API_KEY / CODEX_MODEL, entirely through env vars
# (see entrypoint.sh + configure-codex-provider.sh, and .env.example).
FROM ghcr.io/getpaseo/paseo:latest

USER root

RUN npm install -g @openai/codex

COPY configure-codex-provider.sh /usr/local/bin/configure-codex-provider
COPY entrypoint.sh /usr/local/bin/paseo-codex-entrypoint
RUN chmod +x /usr/local/bin/configure-codex-provider /usr/local/bin/paseo-codex-entrypoint

# Stays root here on purpose (see comment above) - Paseo's own entrypoint,
# which this wraps and hands off to, handles dropping to the `paseo` user
# itself via gosu.

ENTRYPOINT ["/usr/local/bin/paseo-codex-entrypoint"]
# Explicit empty CMD: guarantees a plain `docker run <this image>` (no
# command) passes zero args to the entrypoint, which is what makes Paseo's
# own entrypoint take its "start the daemon" branch rather than its
# "exec the passed command" branch - regardless of whatever CMD the base
# image happened to inherit further up its own build chain.
CMD []
