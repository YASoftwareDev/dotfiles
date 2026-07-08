# Test dotfiles install in a clean Ubuntu environment.
# Requires BuildKit (Docker 20.10+ default) for the optional gh_token secret.
#
# Build & run (installs during build, then drops to shell):
#   docker build -t dotfiles-test:24.04-docker .
#   docker run --rm -it dotfiles-test:24.04-docker
#
# Choose Ubuntu version or install profile:
#   docker build --build-arg UBUNTU=22.04 --build-arg PROFILE=minimal -t dotfiles-test:22.04-minimal .
#   docker build --build-arg PROFILE=workstation -t dotfiles-test:24.04-workstation .
#
# Iterative mode - mount live source, skip the build-time install:
#   docker build --build-arg PROFILE=docker -t dotfiles-test:24.04-docker .
#   docker run --rm -it -v "$PWD":/root/dotfiles dotfiles-test:24.04-docker bash
#   # then inside: cd ~/dotfiles && bash install.sh docker

ARG UBUNTU=24.04
FROM ubuntu:${UBUNTU}

ARG PROFILE=docker
ENV DEBIAN_FRONTEND=noninteractive
ENV SHELL=/usr/bin/zsh
# Prevent powerlevel10k from running the interactive config wizard on first launch
ENV POWERLEVEL9K_DISABLE_CONFIGURATION_WIZARD=true

RUN apt-get -yq update && \
    apt-get -yq install apt-utils git sudo curl ca-certificates && \
    rm -rf /var/lib/apt/lists/*

WORKDIR /root/dotfiles
COPY . .

# Optional gh_token secret -> ~/.curlrc auth header for the install only
# (avoids GitHub's unauthenticated API rate limit); removed after install.
RUN --mount=type=secret,id=gh_token,mode=0444,required=false \
    tok="$(cat /run/secrets/gh_token 2>/dev/null || true)"; \
    if [ -n "$tok" ]; then \
        printf 'header = "Authorization: Bearer %s"\n' "$tok" > ~/.curlrc; \
    fi; \
    bash install.sh ${PROFILE} && chsh -s /usr/bin/zsh root; \
    rc=$?; rm -f ~/.curlrc; exit $rc

CMD ["zsh"]
