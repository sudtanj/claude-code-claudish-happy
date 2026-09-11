# claude-code-claudish-happy

A single Docker image bundling three CLIs for an isolated coding-agent environment:

- **[Claude Code](https://claude.com/claude-code)** — Anthropic's coding agent (`claude`)
- **[Claudish](https://claudish.com)** — run Claude Code against any model (OpenRouter, Gemini, OpenAI, Ollama, ...) via a local proxy (`claudish`)
- **[Happy](https://github.com/slopus/happy)** — mobile/web control for Claude Code or Codex sessions (`happy`)

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

Drop into a shell with all three CLIs on `PATH`:

```bash
docker run -it --rm -v "$PWD":/workspace claude-code-claudish-happy bash
```

## Notes

- The image sets a placeholder `ANTHROPIC_API_KEY` so Claude Code's login dialog
  doesn't block when you're routing everything through Claudish with a
  different provider key; override it with a real key for direct Anthropic use.
- Runs as a non-root user (`agent`) with `/workspace` as the working directory.
