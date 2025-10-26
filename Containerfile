ARG FEDORA_VERSION=42

FROM fedora:${FEDORA_VERSION}

RUN dnf install -y mock mock-core-configs spectool

ARG UID=1000
ARG GID=1000

RUN groupadd -g $GID -o builder && \
    useradd -m -u $UID -g $GID -G mock -o -s /bin/bash builder && \
    echo "builder ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/builder && \
    chmod 0440 /etc/sudoers.d/builder

USER builder

WORKDIR /workspace

ENTRYPOINT [ "env" ]