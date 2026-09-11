# syntax=docker/dockerfile:1

# Isolated container bundling:
#   - Claude Code       (@anthropic-ai/claude-code)
#   - Claudish          (https://claudish.com / https://github.com/MadAppGang/claudish)
#   - Happy CLI         (https://github.com/slopus/happy)
FROM node:22-bookworm-slim

ARG USERNAME=agent
ARG USER_UID=1000
ARG USER_GID=1000

# Base tooling the three CLIs (and their install scripts) expect at runtime:
# git for repo work, curl/ca-certificates for installers and network calls,
# ripgrep for Claude Code's file search, and build-essential/python3 for any
# native npm modules pulled in transitively.
RUN apt-get update && apt-get install -y --no-install-recommends \
        ca-certificates \
        curl \
        git \
        gnupg \
        less \
        procps \
        python3 \
        ripgrep \
        build-essential \
        openssh-client \
        vim \
    && rm -rf /var/lib/apt/lists/*

# Non-root user the CLIs run as.
RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash "${USERNAME}"

# Global npm packages:
#   claude-code -> `claude`
#   claudish    -> `claudish` (multi-model proxy in front of Claude Code)
#   happy       -> `happy`    (mobile/web client wrapper: `happy claude`)
RUN npm install -g \
        @anthropic-ai/claude-code \
        claudish \
        happy \
    && npm cache clean --force

# Workspace the CLIs operate on. Owned by the non-root user so `claude`,
# `claudish`, and `happy` can all write their local state/config dirs.
ENV WORKDIR=/workspace
RUN mkdir -p "${WORKDIR}" \
    && chown -R "${USERNAME}:${USERNAME}" "${WORKDIR}" /home/"${USERNAME}"

USER ${USERNAME}
WORKDIR ${WORKDIR}

# Provide a placeholder key so Claude Code's login dialog doesn't block when
# routing through Claudish; override with a real ANTHROPIC_API_KEY (direct
# Anthropic use) or an OPENROUTER_API_KEY/GEMINI_API_KEY/OPENAI_API_KEY (for
# claudish) at `docker run -e ...` time.
ENV ANTHROPIC_API_KEY=sk-ant-api03-placeholder

COPY --chown=${USERNAME}:${USERNAME} entrypoint.sh /usr/local/bin/entrypoint.sh
USER root
RUN chmod +x /usr/local/bin/entrypoint.sh
USER ${USERNAME}

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]
