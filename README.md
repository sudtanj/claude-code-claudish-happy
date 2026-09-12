# claude-code-claudish-happy

A single Docker image, built on full Ubuntu 24.04, bundling three CLIs for an
isolated coding-agent environment that can actually compile and run the code
it writes:

- **[Claude Code](https://claude.com/claude-code)** — Anthropic's coding agent (`claude`)
- **[Claudish](https://claudish.com)** — run Claude Code against any model (OpenRouter, Gemini, OpenAI, Ollama, ...) via a local proxy (`claudish`)
- **[Happy](https://github.com/slopus/happy)** — mobile/web control for Claude Code or Codex sessions (`happy`)

Also includes a full dev toolchain: build-essential/cmake/gdb (C/C++), Python 3
+ pip/venv, Node.js 22, Deno, Go, Rust (via rustup), a JDK, git, sqlite3, and
the usual CLI utilities (jq, ripgrep, tmux, vim, etc.). The `agent` user has
passwordless `sudo` for ad hoc package installs.

## Quick start with docker compose

```bash
cp .env.example .env
# edit .env and fill in the keys for whichever CLI you plan to run
docker compose run --rm agent claude
docker compose run --rm agent claudish --model openrouter@deepseek/deepseek-r1
docker compose run --rm agent happy claude
docker compose run --rm agent claudish-happy --model openrouter@deepseek/deepseek-r1
docker compose run --rm agent bash
```

The entrypoint checks that the environment variables your chosen command
needs are actually set (from `.env`, `environment:` in `docker-compose.yml`,
or `docker run -e ...`) and fails fast with a clear message if one is
missing, rather than letting the CLI hang on a login prompt.

| Command | Required env var(s) |
|---|---|
| `claude` | `ANTHROPIC_API_KEY` |
| `claudish ...` | one of `OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`, `OLLAMA_HOST` |
| `happy claude` | `ANTHROPIC_API_KEY` |
| `happy codex` | `OPENAI_API_KEY` |
| `claudish-happy ...` | one of `OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`, `OLLAMA_HOST`, `CUSTOM_OPENAI_BASE_URL`, `CUSTOM_ANTHROPIC_BASE_URL` |

See `.env.example` for the full list, and `docker-compose.yml` for where to
put them for compose runs.

### Custom OpenAI-compatible / Anthropic-compatible endpoints

For `claudish` / `claudish-happy`, you can point at your own self-hosted
gateway, vLLM/LM Studio box, or Claude-compatible proxy instead of (or in
addition to) a hosted provider, via:

- `CUSTOM_OPENAI_BASE_URL` (+ optional `CUSTOM_OPENAI_API_KEY`)
- `CUSTOM_ANTHROPIC_BASE_URL` (+ optional `CUSTOM_ANTHROPIC_API_KEY`)

Each is independent - set only the one(s) you need. On startup the entrypoint
registers whichever is set as a Claudish
["customEndpoint"](https://claudish.com) named `custom-openai` /
`custom-anthropic` in `~/.claudish/config.json` (merged with, not replacing,
anything already there - so it's safe to run every start even with the
`claudish-config` volume persisted). Omitting the `*_API_KEY` registers the
endpoint with no auth header, for a local/trusted gateway. Use it with:

```bash
docker compose run --rm agent claudish --model custom-openai@<model-name>
docker compose run --rm agent claudish --model custom-anthropic@<model-name>
```

### Connecting to Happy (pairing your phone/browser)

**Yes, Happy works together with Claude Code *and* Claudish at the same
time** - that's what `claudish-happy` is for (see above): Claudish's
any-model proxy sits underneath, and Happy's mobile/web control wraps that
same session, not a separate one. Pairing is identical either way - `happy
claude` and `claudish-happy` both end up starting Happy, which is the only
part that ever does the pairing dance below. There's nothing Claudish-specific
about it; the two features are independent and compose cleanly.

Happy needs **no API key at all** - it authenticates by pairing a locally
generated keypair to your account, not by an env var. But this image doesn't
just let Happy's own interactive pairing happen wherever it would normally
fall (mid-startup, right before it launches Claude Code) - the entrypoint
detects up front whether a valid Happy credential exists and, if not, runs
pairing **on its own, before Claude Code or Claudish ever start**:

1. Run `happy claude` (or `claudish-happy`, or `happy codex`) as normal.
2. If `~/.happy/access.key` doesn't exist yet, the entrypoint runs Happy's
   own `happy auth login` - a pairing-only subcommand that never touches
   Claude Code/Codex - instead of your actual command.
3. That prints a QR code **and** a plain URL/link (mobile app or web) to the
   terminal. Scan/open it and approve the session from the [Happy
   app](https://app.happy.engineering) or mobile app.
4. Once approved, the entrypoint prints something like:
   ```
   HAPPY_CREDENTIALS_B64=eyJ0b2tlbiI6...
   ```
   and **exits without starting Claude Code or Claudish this run.**
5. Copy that line into `.env` (or `environment:` in `docker-compose.yml`),
   then re-run the exact same command - it now goes straight into your
   session, no pairing step.

That means:
- The container **must have a real terminal attached** for step 3
  (`docker compose run` / `docker run -it` - already the default here via
  `stdin_open`/`tty` in `docker-compose.yml`).
- If `~/.happy` (mounted here as the `happy-config` volume) already has a
  valid `access.key` - from a previous run, or because you set
  `HAPPY_CREDENTIALS_B64` - steps 2-5 are skipped entirely and your command
  runs immediately.
- **No env var is required** for a normal setup using Anthropic's hosted
  Happy server (`api.cluster-fluster.com`) and web app
  (`app.happy.engineering`) - those are just Happy's defaults; pairing works
  the same either way.
- `HAPPY_CREDENTIALS_B64` is a credential (it grants control of your
  Happy-linked Claude Code sessions) - keep it out of git, same as any API
  key in `.env`.

Only set these if you're self-hosting Happy's own server
([`happy-server`](https://github.com/slopus/happy/tree/main/packages/happy-server))
instead of using the hosted one:

| Env var | Default | Purpose |
|---|---|---|
| `HAPPY_SERVER_URL` | `https://api.cluster-fluster.com` | Happy's sync/auth server |
| `HAPPY_WEBAPP_URL` | `https://app.happy.engineering` | Web app the pairing link opens |
| `HAPPY_HOME_DIR` | `~/.happy` | Where credentials/settings are stored |

## Build

```bash
docker build -t claude-code-claudish-happy .
```

## Run

Mount your project into `/workspace` and pass whichever CLI you want as the command.

Plain Claude Code (needs a real Anthropic key):

```bash
docker run -it --rm \
  -v "$PWD":/workspace \
  -e ANTHROPIC_API_KEY=sk-ant-... \
  claude-code-claudish-happy claude
```

Claude Code via Claudish, using e.g. OpenRouter:

```bash
docker run -it --rm \
  -v "$PWD":/workspace \
  -e OPENROUTER_API_KEY=sk-or-v1-... \
  claude-code-claudish-happy claudish --model openrouter@deepseek/deepseek-r1
```

Claude Code wrapped by Happy, for mobile/web control:

```bash
docker run -it --rm \
  -v "$PWD":/workspace \
  -e ANTHROPIC_API_KEY=sk-ant-... \
  claude-code-claudish-happy happy claude
```

Happy automatically connected to the Claude Code session running behind
Claudish, so you get Claudish's any-model routing AND Happy's mobile/web
control over the same session:

```bash
docker run -it --rm \
  -v "$PWD":/workspace \
  -e OPENROUTER_API_KEY=sk-or-v1-... \
  claude-code-claudish-happy claudish-happy --model openrouter@deepseek/deepseek-r1
```

Under the hood, `claudish-happy` points Claudish's `$CLAUDE_PATH` at a small
wrapper (`/usr/local/bin/claude-via-happy`) that runs `happy claude` instead
of the real `claude` binary. Claudish's proxy env
(`ANTHROPIC_BASE_URL`/placeholder `ANTHROPIC_API_KEY`) flows through that
wrapper into the Claude Code process Happy spawns underneath it, so both
tools end up attached to the same session.

Drop into a shell with all three CLIs on `PATH`:

```bash
docker run -it --rm -v "$PWD":/workspace claude-code-claudish-happy bash
```

## Notes

- The image sets a placeholder `ANTHROPIC_API_KEY` so Claude Code's login dialog
  doesn't block when you're routing everything through Claudish with a
  different provider key; override it with a real key for direct Anthropic use.
- Runs as a non-root user (`agent`) with `/workspace` as the working directory.

## CI/CD: auto-publish to Docker Hub

[`.github/workflows/docker-publish.yml`](.github/workflows/docker-publish.yml)
builds and pushes this image to Docker Hub as
[`sudtanj/claude-code-claudish-happy`](https://hub.docker.com/r/sudtanj/claude-code-claudish-happy),
for **both `linux/amd64` and `linux/arm64`**, on every push to the tracked
branch(es). Each run:

1. **`tag` job** - auto-bumps a semver git tag (patch by default, via
   [`anothrNick/github-tag-action`](https://github.com/anothrNick/github-tag-action)).
2. **`build` job** (matrix: one runner per arch) - builds each architecture
   **natively** (amd64 on a regular runner, arm64 on GitHub's native arm64
   runner - no QEMU emulation, which this image's full dev toolchain would
   make painfully slow) and pushes each as an untagged image, by digest.
3. **`merge` job** - combines both digests into a single multi-arch manifest
   and pushes it as both `:latest` and `:<the new tag>` (e.g. `:v1.2.4`) -
   `docker pull` picks the right architecture automatically.

**One-time setup before this will actually run:**

1. Add a repo secret (Settings -> Secrets and variables -> Actions):
   - `DOCKER_HUB_KEY` - a Docker Hub access token with Read & Write scope
     (Docker Hub -> Account Settings -> Security -> Personal access tokens)

   The Docker Hub username (`sudtanj`) is hardcoded in the workflow rather
   than kept as a secret, since it isn't sensitive.
2. Give the workflow's default token push access so the auto-tag step can
   push new tags: Settings -> Actions -> General -> Workflow permissions ->
   "Read and write permissions".
3. Make sure GitHub-hosted arm64 runners (the `ubuntu-24.04-arm` label) are
   available to this repo - free for public repos; on a private repo it
   needs a plan that includes them. If that label isn't available, replace
   the arm64 entry's `runner:` in the `build` job's matrix with
   `ubuntu-latest` and add a `docker/setup-qemu-action` step - it'll still
   work, just much slower (QEMU-emulated).

The workflow triggers on pushes to `main`.
