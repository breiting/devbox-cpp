# Copyright (C) 2025 Bernhard Reitinger
#
# THIS CODE AND INFORMATION ARE PROVIDED "AS IS" WITHOUT WARRANTY OF ANY
# KIND, EITHER EXPRESSED OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE
# IMPLIED WARRANTIES OF MERCHANTABILITY AND/OR FITNESS FOR A
# PARTICULAR PURPOSE.

# ---------- Stage 0: Build Neovim 0.11 from source ----------
FROM debian:trixie AS nvim-builder

ARG DEBIAN_FRONTEND=noninteractive
ARG NVIM_TAG=v0.11.4

RUN apt-get update && apt-get install -y --no-install-recommends \
    git gettext libtool libtool-bin autoconf automake cmake \
    pkg-config unzip curl doxygen ca-certificates build-essential && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /tmp
RUN git clone --depth 1 --branch ${NVIM_TAG} https://github.com/neovim/neovim.git
WORKDIR /tmp/neovim
RUN make CMAKE_BUILD_TYPE=RelWithDebInfo CMAKE_INSTALL_PREFIX=/usr/local && \
    make install

# ---------- Stage 1: Runtime ----------
FROM debian:trixie

ARG DEBIAN_FRONTEND=noninteractive
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000
ARG DOTFILES_REPO=""
ARG DOTFILES_BRANCH=""
ARG GIT_NAME=""
ARG GIT_EMAIL=""

# Basis-Tools
RUN apt-get update && apt-get install -y --no-install-recommends \
    zsh tmux fzf ripgrep \
    git curl wget ca-certificates unzip xz-utils \
    gcc g++ clang clangd gdb lldb \
    stow ssh sudo unzip ack openssh-client \
    cmake pkg-config make tree lazygit \
    python3 python3-pip python3-venv \
    build-essential golang npm \
    less locales && \
    rm -rf /var/lib/apt/lists/*

# Locales
RUN sed -i 's/# *de_AT.UTF-8 UTF-8/de_AT.UTF-8 UTF-8/' /etc/locale.gen && \
    sed -i 's/# *de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen && \
    sed -i 's/# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Neovim from Stage 0
COPY --from=nvim-builder /usr/local /usr/local

# User/Group (idempotent)
RUN if ! getent group ${GID} >/dev/null; then groupadd -g ${GID} ${USERNAME}; fi && \
    if ! id -u ${USERNAME} >/dev/null 2>&1; then \
      useradd -m -s /usr/bin/zsh -u ${UID} -g ${GID} ${USERNAME}; \
    fi

# Create working directory and set permissions
RUN install -d -o ${UID} -g ${GID} /work && \
    install -d -o ${UID} -g ${GID} /data

# SSH known_hosts preloading
RUN mkdir -p /etc/ssh && \
    ssh-keyscan -t rsa,ecdsa,ed25519 github.com >> /etc/ssh/ssh_known_hosts && \
    ssh-keyscan -t rsa,ecdsa,ed25519 gitlab.com >> /etc/ssh/ssh_known_hosts && \
    ssh-keyscan -t rsa,ecdsa,ed25519 bitbucket.org >> /etc/ssh/ssh_known_hosts

# Allow sudo w/o password
RUN echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers

# Let XDG with with mounted volume und /data
ENV XDG_DATA_HOME=/data/.local/share
ENV XDG_STATE_HOME=/data/.local/state
ENV XDG_CACHE_HOME=/data/.cache

# Set username and password
USER ${USERNAME}
ENV HOME=/home/${USERNAME}
WORKDIR /work

# Clone Dotfiles
RUN if [ -n "${DOTFILES_REPO}" ]; then \
      if [ -n "${DOTFILES_BRANCH}" ]; then \
        git clone --depth 1 --branch "${DOTFILES_BRANCH}" "${DOTFILES_REPO}" "${HOME}/dotfiles"; \
      else \
        git clone --depth 1 "${DOTFILES_REPO}" "${HOME}/dotfiles"; \
      fi && \
      cd "${HOME}/dotfiles" && \
      [ -x ./bootstrap.sh ] && ./bootstrap.sh || true ; \
    fi

ENV TERM=xterm-256color
SHELL ["/usr/bin/zsh", "-lc"]

# minimal Shell-Defaults
RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && \
    echo 'eval "$(fzf --zsh)"' >> ~/.zshrc || true

# ---- Git Identity ----
RUN if [ -n "${GIT_NAME}" ] && [ -n "${GIT_EMAIL}" ]; then \
      git config --global user.name "${GIT_NAME}" && \
      git config --global user.email "${GIT_EMAIL}"; \
    fi

# Make sure to make zsh directory for history file
RUN mkdir -p /data/.local/share/zsh

CMD ["/usr/bin/zsh"]
