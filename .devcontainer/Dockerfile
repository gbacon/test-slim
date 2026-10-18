FROM mcr.microsoft.com/devcontainers/base:ubuntu

ENV DEBIAN_FRONTEND=noninteractive
ENV LANG=C.UTF-8
ENV LC_ALL=C.UTF-8

RUN apt-get update \
 && apt-get install -y --no-install-recommends \
      perl \
      perl-doc \
      cpanminus \
      build-essential \
      default-jre \
      curl \
      ca-certificates \
      nodejs \
      npm \
 && rm -rf /var/lib/apt/lists/*

WORKDIR /tmp/bootstrap
COPY cpanfile .
RUN cpanm --notest --installdeps .

ARG FITNESSE_VERSION
ARG FITNESSE_SHA256

RUN test -n "$FITNESSE_VERSION" \
 && test -n "$FITNESSE_SHA256" \
 && mkdir -p /opt/fitnesse \
 && curl --fail --location --retry 3 \
      "https://github.com/unclebob/fitnesse/releases/download/v${FITNESSE_VERSION}/fitnesse-${FITNESSE_VERSION}-standalone.jar" \
      -o /opt/fitnesse/fitnesse.jar \
 && echo "${FITNESSE_SHA256}  /opt/fitnesse/fitnesse.jar" \
      | sha256sum -c -
