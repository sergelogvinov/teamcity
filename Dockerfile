# https://github.com/JetBrains/teamcity-docker-images
#

FROM jetbrains/teamcity-server:2022.10.3 AS teamcity
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

FROM jetbrains/teamcity-minimal-agent:2023.05 AS teamcity-agent
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

ARG HELM_VERSION=3.11.2 NERDCTL_VERSION=1.2.1
RUN wget https://dl.k8s.io/v1.23.16/kubernetes-client-linux-amd64.tar.gz -O /tmp/kubernetes-client-linux-amd64.tar.gz && \
    cd /tmp && tar -xzf /tmp/kubernetes-client-linux-amd64.tar.gz && mv kubernetes/client/bin/kubectl /usr/bin/kubectl && \
    wget https://get.helm.sh/helm-v${HELM_VERSION}-linux-amd64.tar.gz -O /tmp/helm.tar.gz && \
    echo "781d826daec584f9d50a01f0f7dadfd25a3312217a14aa2fbb85107b014ac8ca /tmp/helm.tar.gz" | sha256sum -c - && \
    cd /tmp && tar -xzf /tmp/helm.tar.gz && mv linux-amd64/helm /usr/bin/helm && rm -rf /tmp/* && \
    wget https://github.com/containerd/nerdctl/releases/download/v${NERDCTL_VERSION}/nerdctl-${NERDCTL_VERSION}-linux-amd64.tar.gz -O /tmp/nerdctl.tar.gz && \
    echo "67aa5cf2a32a3dc0c335b96133daee4d2764d9c1a4d86a38398c4995d2df2176 /tmp/nerdctl.tar.gz" | sha256sum -c - && \
    cd /tmp && tar -xzf /tmp/nerdctl.tar.gz && mv nerdctl /usr/bin/nerdctl && rm -rf /tmp/* && \
    wget https://github.com/mozilla/sops/releases/download/v3.7.3/sops-v3.7.3.linux -O /tmp/sops && \
    echo "913515e57d0112840540dc3c56370ff9 /tmp/sops" | md5sum -c - && \
    install -o root -g root /tmp/sops /usr/bin/sops && rm -rf /tmp/*

COPY --from=docker:20.10-cli /usr/libexec/docker/cli-plugins/docker-compose /usr/libexec/docker/cli-plugins/docker-compose
COPY --from=docker/buildx-bin:0.10.4 /buildx /usr/libexec/docker/cli-plugins/docker-buildx
COPY --from=aquasec/trivy:0.38.3 /usr/local/bin/trivy /usr/local/bin/trivy

ENV CONFIG_FILE=/home/buildagent/conf/buildAgent.properties
ENV DOCKER_HOST=tcp://docker:2376

WORKDIR /home/buildagent

USER buildagent

# helm hooks error log https://github.com/helm/helm/pull/11228
COPY --from=helm --chown=root:root /go/src/bin/helm /usr/bin/helm

COPY --chown=root:root etc/ /etc/
RUN helm plugin install https://github.com/jkroepke/helm-secrets --version v3.15.0
