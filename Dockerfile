# https://github.com/JetBrains/teamcity-docker-images
#

FROM jetbrains/teamcity-server:2023.05-nanoserver-2004 AS teamcity
LABEL org.opencontainers.image.source https://github.com/sergelogvinov/teamcity

USER root
RUN curl -LfsSo /opt/teamcity/webapps/ROOT/WEB-INF/lib/postgresql-42.5.1.jar https://jdbc.postgresql.org/download/postgresql-42.5.1.jar && \
    echo "378f8a2ddab2564a281e5f852800e2e9 /opt/teamcity/webapps/ROOT/WEB-INF/lib/postgresql-42.5.1.jar" | md5sum -c - && \
    curl -LfsSo /opt/teamcity/webapps/ROOT/WEB-INF/plugins/teamcity-oauth-1.1.9.zip https://github.com/pwielgolaski/teamcity-oauth/releases/download/teamcity-oauth-1.1.9/teamcity-oauth-1.1.9.zip && \
    echo "54397b7e08831e179e12d328e240ee15 /opt/teamcity/webapps/ROOT/WEB-INF/plugins/teamcity-oauth-1.1.9.zip" | md5sum -c -

RUN install -o tcuser -g tcuser -d /data -d /home/tcuser
COPY --chown=tcuser:tcuser config/server.xml /opt/teamcity/conf/server.xml

# USER tcuser
WORKDIR /opt/teamcity
CMD ["/opt/teamcity/bin/teamcity-server.sh","run"]

###

FROM golang:1.18-bullseye AS helm

WORKDIR /go/src/
RUN git clone --single-branch --depth 2 --branch hooks-logs https://github.com/sergelogvinov/helm.git .
RUN make

###

FROM jetbrains/teamcity-minimal-agent:2023.05.2 AS teamcity-agent
LABEL org.opencontainers.image.source https://github.com/sergelogvinov/teamcity

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y software-properties-common vim-tiny curl wget git make zip rsync docker.io && \
    apt-get install -y ansible python3-pip python3-boto && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/buildagent/conf /home/buildagent/.ansible && \
    chown -R buildagent.buildagent /opt/buildagent /home/buildagent

COPY --from=docker:23.0.6-cli /usr/local/libexec/docker/cli-plugins/docker-compose /usr/local/libexec/docker/cli-plugins/docker-compose
COPY --from=docker/buildx-bin:0.10.4 /buildx /usr/local/libexec/docker/cli-plugins/docker-buildx
COPY --from=ghcr.io/aquasecurity/trivy:0.42.1 /usr/local/bin/trivy /usr/local/bin/trivy

COPY --from=bitnami/kubectl:1.24.15 /opt/bitnami/kubectl/bin/kubectl /usr/local/bin/kubectl
COPY --from=alpine/helm:3.12.1 /usr/bin/helm /usr/bin/helm
COPY --from=ghcr.io/sergelogvinov/sops:3.7.3  /usr/bin/sops /usr/bin/sops
COPY --from=ghcr.io/sergelogvinov/vals:0.25.0 /usr/bin/vals /usr/bin/vals

ENV CONFIG_FILE=/home/buildagent/conf/buildAgent.properties
ENV DOCKER_HOST=tcp://docker:2376

WORKDIR /home/buildagent

USER buildagent

# helm hooks error log https://github.com/helm/helm/pull/11228
COPY --from=helm --chown=root:root /go/src/bin/helm /usr/bin/helm

COPY --chown=root:root etc/ /etc/
RUN helm plugin install https://github.com/jkroepke/helm-secrets --version v3.15.0 && \
    helm repo add bitnami  https://charts.bitnami.com/bitnami && \
    helm repo add sinextra https://helm-charts.sinextra.dev && \
    helm repo update
