export UID_HOST=$(id -u)
export GID_HOST=$(id -g)

podman build \
  --file Containerfile \
  --tag dev-nvim:0.11 \
  --build-arg USERNAME=dev \
  --build-arg UID=${UID_HOST} \
  --build-arg GID=${GID_HOST} \
  --build-arg DOTFILES_REPO="https://github.com/breiting/dotfiles.git" \
  --build-arg DOTFILES_BRANCH="main" \
  .

