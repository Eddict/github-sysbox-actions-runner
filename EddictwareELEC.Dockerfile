#
# Github-Actions runner image.
#

FROM rodnymolina588/ubuntu-jammy-docker
LABEL maintainer="eddictnl@docker.com"

ENV AGENT_TOOLSDIRECTORY=/opt/hostedtoolcache
RUN mkdir -p /opt/hostedtoolcache

ARG GH_RUNNER_VERSION="2.331.0"

ARG TARGETPLATFORM

LABEL org.opencontainers.image.version="${GH_RUNNER_VERSION}"

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

RUN apt-get update && apt-get install -y \
  git make gcc g++ bc bzip2 unzip wget python3 python3-pip xz-utils \
  libssl-dev libncurses5-dev libncursesw5-dev zlib1g-dev gawk flex gettext \
  xsltproc rsync file \
  xfonts-utils libjson-perl rdfind libparse-yapp-perl gperf \
  libxml-parser-perl patchutils lzop \
  default-jre zip
    
RUN apt-get update && apt-get install -y --no-install-recommends dumb-init jq \
  && groupadd -g 121 runner \
  && useradd -mr -d /home/runner -u 1001 -g 121 runner \
  && usermod -aG sudo runner \
  && usermod -aG docker runner \
  && echo '%sudo ALL=(ALL) NOPASSWD: ALL' >> /etc/sudoers

WORKDIR /actions-runner
COPY scr/install_actions.sh /actions-runner

RUN chmod +x /actions-runner/install_actions.sh \
  && /actions-runner/install_actions.sh ${GH_RUNNER_VERSION} ${TARGETPLATFORM} \
  && rm /actions-runner/install_actions.sh \
  && chown runner /_work /actions-runner /opt/hostedtoolcache

COPY scr/token.sh scr/entrypoint.sh scr/app_token.sh /
RUN chmod +x /token.sh /entrypoint.sh /app_token.sh

ENTRYPOINT ["/entrypoint.sh"]
CMD ["./bin/Runner.Listener", "run", "--startuptype", "service"]
