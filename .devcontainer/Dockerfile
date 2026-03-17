FROM mcr.microsoft.com/devcontainers/base:ubuntu

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      perl \
      cpanminus \
      build-essential \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /workspaces/test-slim
COPY . .

RUN cpanm --notest --installdeps .