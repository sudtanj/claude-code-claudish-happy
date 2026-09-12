# syntax=docker/dockerfile:1

# Isolated, full-featured Ubuntu dev environment bundling:
#   - Claude Code       (@anthropic-ai/claude-code)
#   - Claudish          (https://claudish.com / https://github.com/MadAppGang/claudish)
#   - Happy CLI         (https://github.com/slopus/happy)
# plus common compilers/interpreters so Claude Code can actually build and
# run the code it writes (C/C++, Python, Go, Rust, Node, Deno), not just
# edit it.
FROM ubuntu:24.04

ARG USERNAME=agent
ARG USER_UID=1000
ARG USER_GID=1000
ARG NODE_MAJOR=22
ARG GO_VERSION=1.23.4
ARG DENO_VERSION=v2.1.4

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

# Base OS tooling + full build/dev toolchain:
#   - build-essential, cmake, pkg-config, gdb  -> compile & debug C/C++
#   - python3/pip/venv                         -> run & build Python
#   - default-jdk                              -> compile & run Java
#   - git, curl, wget, unzip, jq, ripgrep, ...  -> everyday CLI/dev tooling
RUN apt-get update && apt-get install -y --no-install-recommends \
        apt-transport-https \
        autoconf \
        automake \
        build-essential \
        ca-certificates \
        cmake \
        curl \
        default-jdk \
        gdb \
        git \
        gnupg \
        htop \
        jq \
        less \
        libssl-dev \
        libtool \
        locales \
        lsof \
        make \
        openssh-client \
        pkg-config \
        procps \
        python3 \
        python3-pip \
        python3-venv \
        ripgrep \
        sqlite3 \
        sudo \
        tmux \
        unzip \
        vim \
        wget \
        zip \
        zsh \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Node.js (required to run/install the npm-based CLIs below) from NodeSource.
RUN curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && rm -rf /var/lib/apt/lists/*

# Go toolchain.
RUN curl -fsSL "https://go.dev/dl/go${GO_VERSION}.linux-$(dpkg --print-architecture).tar.gz" -o /tmp/go.tar.gz \
    && tar -C /usr/local -xzf /tmp/go.tar.gz \
    && rm /tmp/go.tar.gz
ENV PATH="/usr/local/go/bin:${PATH}"

# Deno runtime, installed system-wide from the official release archive.
RUN set -eux; \
    case "$(dpkg --print-architecture)" in \
        amd64) DENO_ARCH=x86_64-unknown-linux-gnu ;; \
        arm64) DENO_ARCH=aarch64-unknown-linux-gnu ;; \
        *) echo "unsupported architecture for deno" >&2; exit 1 ;; \
    esac; \
    curl -fsSL "https://github.com/denoland/deno/releases/download/${DENO_VERSION}/deno-${DENO_ARCH}.zip" -o /tmp/deno.zip \
    && unzip -q /tmp/deno.zip -d /usr/local/bin \
    && rm /tmp/deno.zip \
    && chmod +x /usr/local/bin/deno

# Non-root user the CLIs and any compiled programs run as, with passwordless
# sudo so build tooling (package installs, etc.) can still be used ad hoc.
RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
    && useradd --uid "${USER_UID}" --gid "${USER_GID}" --create-home --shell /bin/bash "${USERNAME}" \
    && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/"${USERNAME}" \
    && chmod 0440 /etc/sudoers.d/"${USERNAME}"

# Rust toolchain, installed as the non-root user (rustup's expected mode).
USER ${USERNAME}
ENV RUSTUP_HOME=/home/${USERNAME}/.rustup \
    CARGO_HOME=/home/${USERNAME}/.cargo \
    PATH="/home/${USERNAME}/.cargo/bin:${PATH}"
RUN curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --default-toolchain stable --profile minimal

USER root

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
# `claudish`, and `happy` can all write their local state/config dirs, and so
# compiled artifacts land with sane ownership.
ENV WORKDIR=/workspace
RUN mkdir -p "${WORKDIR}" \
    && chown -R "${USERNAME}:${USERNAME}" "${WORKDIR}" /home/"${USERNAME}"

COPY --chown=${USERNAME}:${USERNAME} entrypoint.sh /usr/local/bin/entrypoint.sh
COPY --chown=${USERNAME}:${USERNAME} claude-via-happy.sh /usr/local/bin/claude-via-happy
COPY --chown=${USERNAME}:${USERNAME} configure-claudish-endpoints.sh /usr/local/bin/configure-claudish-endpoints
COPY --chown=${USERNAME}:${USERNAME} configure-happy-credentials.sh /usr/local/bin/configure-happy-credentials
RUN chmod +x /usr/local/bin/entrypoint.sh /usr/local/bin/claude-via-happy \
        /usr/local/bin/configure-claudish-endpoints /usr/local/bin/configure-happy-credentials

USER ${USERNAME}
WORKDIR ${WORKDIR}

# Provide a placeholder key so Claude Code's login dialog doesn't block when
# routing through Claudish; override with a real ANTHROPIC_API_KEY (direct
# Anthropic use) or an OPENROUTER_API_KEY/GEMINI_API_KEY/OPENAI_API_KEY (for
# claudish) at `docker run -e ...` time.
ENV ANTHROPIC_API_KEY=sk-ant-api03-placeholder

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["claude"]
