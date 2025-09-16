# Makefile

# ===== Settings =====
ENGINE ?= podman
IMAGE  ?= dev-nvim
TAG    ?= 0.11
NAME   ?= dev-nvim
VOLUME_DATA ?= devdata
USERNAME ?= dev

UID_HOST := $(shell id -u)
GID_HOST := $(shell id -g)

# SELinux Label für Podman-Bind-Mounts; bei docker leer
ifeq ($(ENGINE),podman)
  MOUNT_LABEL := :Z
else
  MOUNT_LABEL :=
endif

# ===== Phony =====
.PHONY: build run volume-create clean rmimage rmi volume-rm run-docker run-podman

# ===== Build =====
build:
	$(ENGINE) build \
	  --file Containerfile \
	  --tag $(IMAGE):$(TAG) \
	  --build-arg USERNAME=$(USERNAME) \
	  --build-arg UID=$(UID_HOST) \
	  --build-arg GID=$(GID_HOST) \
	  --build-arg DOTFILES_REPO="https://github.com/breiting/dotfiles.git" \
	  --build-arg DOTFILES_BRANCH="main" \
	  .

# ===== Volume anlegen, falls nicht vorhanden =====
volume-create:
	-$(ENGINE) volume inspect $(VOLUME_DATA) >/dev/null 2>&1 || $(ENGINE) volume create $(VOLUME_DATA)

# ===== Run (aktuelles Projekt nach /work, /data als persistentes Volume) =====
run: volume-create
	$(ENGINE) run --rm -it \
	  --name $(NAME) \
	  -e TZ=Europe/Vienna \
	  --volume="$(PWD):/work$(MOUNT_LABEL)" \
	  --volume="$(VOLUME_DATA):/data$(MOUNT_LABEL)" \
	  $(IMAGE):$(TAG)

# ===== Docker/Podman Convenience =====
run-docker:
	@$(MAKE) run ENGINE=docker

run-podman:
	@$(MAKE) run ENGINE=podman

# ===== Aufräumen =====
clean:
	-$(ENGINE) rm -f $(NAME) 2>/dev/null || true

rmimage rmi:
	-$(ENGINE) rmi $(IMAGE):$(TAG) 2>/dev/null || true

volume-rm:
	-$(ENGINE) volume rm $(VOLUME_DATA) 2>/dev/null || true

