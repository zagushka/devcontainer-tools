FROM node:22-bookworm

RUN apt-get update && apt-get install -y --no-install-recommends \
    git openssh-client ca-certificates bash sudo \
  && rm -rf /var/lib/apt/lists/*

RUN echo "node ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/node \
  && chmod 0440 /etc/sudoers.d/node

RUN corepack enable
RUN mkdir -p /pnpm-store && chown -R node:node /pnpm-store

USER node
WORKDIR /workspaces
