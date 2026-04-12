FROM debian:12

ARG USERNAME=tester
ARG USER_UID=1000
ARG USER_GID=1000

# Use internal mirror for faster apt in office network
RUN sed -i 's|deb.debian.org|mirrors.byted.org|g' /etc/apt/sources.list.d/debian.sources

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    sudo \
    curl \
    ca-certificates \
    git \
  && rm -rf /var/lib/apt/lists/*

RUN groupadd --gid "${USER_GID}" "${USERNAME}" \
  && useradd --uid "${USER_UID}" --gid "${USER_GID}" -m -s /bin/bash "${USERNAME}" \
  && echo "${USERNAME} ALL=(ALL) NOPASSWD:ALL" >"/etc/sudoers.d/${USERNAME}" \
  && chmod 0440 "/etc/sudoers.d/${USERNAME}"

# NOTE: chezmoi is NOT pre-installed — the cold-boot test installs it.

USER ${USERNAME}
WORKDIR /home/${USERNAME}

CMD ["bash"]
