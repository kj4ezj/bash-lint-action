FROM ubuntu:22.04
# install dependencies
ENV DEBIAN_FRONTEND='noninteractive'
RUN apt-get update && \
    apt-get install -y \
        jq \
        python3-bashate \
        shellcheck && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*
# pack script
COPY lint.sh /lint.sh
RUN /lint.sh
