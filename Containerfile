# ---------- Stage 0: Build Neovim 0.11 from source (arch-agnostic) ----------
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
# konfigurierbar: User + IDs (für Besitzrechte bei Bind-Mounts)
ARG USERNAME=dev
ARG UID=1000
ARG GID=1000
# optional: Dotfiles
ARG DOTFILES_REPO=""
ARG DOTFILES_BRANCH=""

# Basis-Tools & C/C++ Toolchain & LSPs & OCCT
RUN apt-get update && apt-get install -y --no-install-recommends \
    zsh tmux fzf ripgrep \
    git curl wget ca-certificates unzip xz-utils \
    gcc g++ clang clangd gdb lldb \
	stow \
    cmake pkg-config make \
    python3 python3-pip \
    build-essential \
    less locales && \
    rm -rf /var/lib/apt/lists/*

# Locales
RUN sed -i 's/# *de_AT.UTF-8 UTF-8/de_AT.UTF-8 UTF-8/' /etc/locale.gen && \
    sed -i 's/# *de_DE.UTF-8 UTF-8/de_DE.UTF-8 UTF-8/' /etc/locale.gen && \
    sed -i 's/# *en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen && \
    locale-gen
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Take neovim from build
COPY --from=nvim-builder /usr/local /usr/local

RUN if ! getent group ${GID} >/dev/null; then \
      groupadd -g ${GID} ${USERNAME}; \
    fi && \
    if ! id -u ${USERNAME} >/dev/null 2>&1; then \
      useradd -m -s /usr/bin/zsh -u ${UID} -g ${GID} ${USERNAME}; \
    fi

# Create work directory and change ownership
RUN install -d -o ${UID} -g ${GID} /work

USER ${USERNAME}
ENV HOME=/home/${USERNAME}
WORKDIR /work

# OPTIONAL: Clone Dotfiles
RUN if [ -n "$DOTFILES_REPO" ]; then \
      git clone --depth 1 ${DOTFILES_REPO} dotfiles$( [ -n "$DOTFILES_BRANCH" ] && echo " -b ${DOTFILES_BRANCH}" || true ); \
      cd dotfiles || cd dotfiles; \
      if [ -x ./update.sh ]; then ./update.sh || true; fi; \
      # Fallback
      [ -f .zshrc ] && ln -sf $(pwd)/.zshrc ${HOME}/.zshrc || true; \
      [ -f .tmux.conf ] && ln -sf $(pwd)/.tmux.conf ${HOME}/.tmux.conf || true; \
      [ -d .config/nvim ] && mkdir -p ${HOME}/.config && ln -sfn $(pwd)/.config/nvim ${HOME}/.config/nvim || true; \
    fi


ENV TERM=xterm-256color

# Default-Shell zsh
SHELL ["/usr/bin/zsh", "-lc"]

RUN echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.zshrc && \
    echo 'eval "$(fzf --zsh)"' >> ~/.zshrc || true

CMD ["/usr/bin/zsh"]

