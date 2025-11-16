# Lightweight prebuilt-style container for shell/script development
FROM mcr.microsoft.com/devcontainers/base:ubuntu

ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    ca-certificates \
    curl \
    git \
    make \
    jq \
    sudo \
    iproute2 \
    openssh-client \
    build-essential \
    unzip \
    shellcheck \
    docker.io \
    bash-completion \
  && rm -rf /var/lib/apt/lists/*

# Install shfmt (formatting for shell scripts)
RUN SHFMT_VER=3.12.0 \
  && curl -fsSL -o /usr/local/bin/shfmt "https://github.com/mvdan/sh/releases/download/v${SHFMT_VER}/shfmt_v${SHFMT_VER}_linux_amd64" \
  && chmod +x /usr/local/bin/shfmt || true

# Create workspace dir
RUN mkdir -p /workspaces

# Use the default non-root user provided by the base devcontainer images
USER vscode
