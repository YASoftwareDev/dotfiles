# Test dotfiles install in a clean Ubuntu environment.
#
# Build & run (installs during build, then drops to shell):
#   docker build -t dotfiles-test:24.04-docker .
#   docker run --rm -it dotfiles-test:24.04-docker
#
# Choose Ubuntu version or install profile:
#   docker build --build-arg UBUNTU=22.04 --build-arg PROFILE=minimal -t dotfiles-test:22.04-minimal .
#   docker build --build-arg PROFILE=workstation -t dotfiles-test:24.04-workstation .
#
# Iterative mode — mount live source, skip the build-time install:
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

RUN bash install.sh ${PROFILE} && \
    chsh -s /usr/bin/zsh root

CMD ["zsh"]
