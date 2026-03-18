FROM mcr.microsoft.com/devcontainers/base:ubuntu

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      perl \
      cpanminus \
      build-essential \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/bootstrap
COPY cpanfile .
RUN cpanm --notest --installdeps .