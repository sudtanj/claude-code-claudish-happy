# paseo-codex

> Part of a multi-image repo - see the [root README](../README.md) for how
> the generic per-folder build workflow works. Everything below is scoped
> to this folder; run these commands from inside it
> (`cd paseo-codex` first if you're at the repo root).

[**Paseo**](https://github.com/getpaseo/paseo) - a daemon + bundled web UI
for running and orchestrating coding agent CLIs remotely - layered with
[**Codex CLI**](https://github.com/openai/codex), OpenAI's coding agent,
with BYOK support for any OpenAI-Responses-API-compatible endpoint.

Paseo's own published image ships no agent CLIs by default - its docs
document a child-image pattern (`FROM` the base image, `USER root`,
`npm install -g` whichever CLIs you want) that this image follows exactly,
adding only this repo's own Codex BYOK wiring on top, entirely through env
vars.

## Quick start with docker compose

Two compose files, depending on whether you want to build from this repo's
source or just run the already-published image:

- **`docker-compose.yml`** - builds the image locally from the `Dockerfile`
  in this repo. Use this if you're modifying the image itself.
- **`docker-compose.hub.yml`** - pulls
  [`sudtanj/paseo-codex`](https://hub.docker.com/r/sudtanj/paseo-codex)
  from Docker Hub instead of building. Use this if you just want to run it -
  only this file and a `.env` are needed, no clone/build required.

```bash
cp .env.example .env
# edit .env - at minimum set PASEO_PASSWORD and OPENAI_API_KEY (or the
# CODEX_BASE_URL BYOK vars)

# Build locally:
docker compose up -d

# Or pull the published image instead:
docker compose -f docker-compose.hub.yml up -d
```

Paseo's web UI + API is then reachable at `http://localhost:6767`. The
current directory is mounted at `/workspace` for Codex sessions to work in;
`~/home/paseo` (Paseo's own state, plus `~/.codex`) persists in the
`paseo-home` named volume across restarts.

You can also run Codex directly inside the running container, per Paseo's
own docs:

```bash
docker compose exec --user paseo paseo-codex codex
```

## Configuration (all via env vars)

See `.env.example` for the full, commented list. Everything is set via
environment variables so you can customize it entirely from your own
`docker-compose.yml` / `.env` - no image rebuild needed for config changes.

| Variable | Purpose |
|---|---|
| `PASEO_PASSWORD` | Auth for Paseo's daemon/web UI. Strongly recommended for anything network-reachable. |
| `PASEO_LISTEN` | Listen address (default `0.0.0.0:6767`). |
| `PASEO_HOSTNAMES` | Comma-separated allow-listed hostnames, for use behind a reverse proxy. |
| `OPENAI_API_KEY` | Direct OpenAI API key - passed straight through to Codex sessions Paseo launches. |
| `CODEX_BASE_URL` | Codex BYOK: point Codex at your own OpenAI-Responses-API-compatible endpoint instead of `api.openai.com`. |
| `CODEX_API_KEY` | Optional key for the BYOK endpoint (a local/trusted gateway needs none). |
| `CODEX_MODEL` | Optional default model for Codex. |
| `GH_TOKEN` | GitHub token for cloning/pulling private repos into `/workspace` - wired up for both `gh` and plain `git` automatically. |

### Codex BYOK caveat

Codex CLI only speaks the newer **Responses API** (`/v1/responses`), not
the more common Chat Completions format that most third-party
"OpenAI-compatible" gateways implement. Your `CODEX_BASE_URL` endpoint has
to actually support the Responses API, or requests will fail even though
Codex itself starts fine.

### Cloning private repos

Set `GH_TOKEN` (a GitHub personal access token with `repo`/`contents:read`
scope) and both `gh` subcommands and plain `git clone`/`git pull` of
private repos work out of the box inside `/workspace` - no SSH keys or
manual `gh auth login` needed.

## How it's built

`Dockerfile` starts `FROM ghcr.io/getpaseo/paseo:latest`, installs
`@openai/codex` and GitHub CLI (`gh`, from GitHub's own apt repo - the base
image is Debian bookworm-slim) as root, and wraps Paseo's own entrypoint
with a thin `entrypoint.sh` that runs `configure-codex-provider.sh`
(generates `~/.codex/config.toml` from the env vars above) and, if
`GH_TOKEN`/`GITHUB_TOKEN` is set, `gh auth setup-git` (wires the token into
git's credential helper) before handing off, unchanged, to Paseo's original
entrypoint - same `tini` PID-1 wrapping, same root -> `paseo`-user
privilege drop via `gosu`, same daemon-start vs. exec-passthrough
branching.
