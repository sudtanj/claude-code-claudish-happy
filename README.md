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
| `claudish-happy ...` | one of `OPENROUTER_API_KEY`, `GEMINI_API_KEY`, `OPENAI_API_KEY`, `OLLAMA_HOST` |

See `.env.example` for the full list, and `docker-compose.yml` for where to
put them for compose runs.

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
