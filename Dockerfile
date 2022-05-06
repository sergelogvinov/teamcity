# https://github.com/JetBrains/teamcity-docker-images
#

FROM jetbrains/teamcity-server:2022.04 AS teamcity
LABEL org.opencontainers.image.source https://github.com/sergelogvinov/teamcity

USER root
RUN curl -LfsSo /opt/teamcity/webapps/ROOT/WEB-INF/lib/postgresql-42.2.23.jar https://jdbc.postgresql.org/download/postgresql-42.2.23.jar && \
    echo "b891abdb925d3553da695bbae54921ea /opt/teamcity/webapps/ROOT/WEB-INF/lib/postgresql-42.2.23.jar" | md5sum -c - && \
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

FROM jetbrains/teamcity-minimal-agent:2022.04 AS teamcity-agent
LABEL org.opencontainers.image.source https://github.com/sergelogvinov/teamcity

USER root
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y software-properties-common vim curl wget git make zip rsync docker.io && \
    apt-get install -y ansible python3-pip python3-boto && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/buildagent/conf /home/buildagent/.ansible && \
    chown -R buildagent.buildagent /opt/buildagent /home/buildagent

RUN wget https://dl.k8s.io/v1.22.4/kubernetes-client-linux-amd64.tar.gz -O /tmp/kubernetes-client-linux-amd64.tar.gz && \
    cd /tmp && tar -xzf /tmp/kubernetes-client-linux-amd64.tar.gz && mv kubernetes/client/bin/kubectl /usr/bin/kubectl && \
    wget https://get.helm.sh/helm-v3.8.2-linux-amd64.tar.gz -O /tmp/helm.tar.gz && \
    echo "6cb9a48f72ab9ddfecab88d264c2f6508ab3cd42d9c09666be16a7bf006bed7b /tmp/helm.tar.gz" | sha256sum -c - && \
    cd /tmp && tar -xzf /tmp/helm.tar.gz && mv linux-amd64/helm /usr/bin/helm && rm -rf /tmp/* && \
    wget https://github.com/containerd/nerdctl/releases/download/v0.19.0/nerdctl-0.19.0-linux-amd64.tar.gz -O /tmp/nerdctl.tar.gz && \
    echo "9cf4d1a2b18baf0c713d7746f896fd6a9d18a130ea8f590c6ed11474748b1733 /tmp/nerdctl.tar.gz" | sha256sum -c - && \
    cd /tmp && tar -xzf /tmp/nerdctl.tar.gz && mv nerdctl /usr/bin/nerdctl && rm -rf /tmp/* && \
    wget https://github.com/mozilla/sops/releases/download/v3.7.1/sops-v3.7.1.linux -O /tmp/sops && \
    echo "6d4a087b325525f160c9a68fd2fd2df8 /tmp/sops" | md5sum -c - && \
    install -o root -g root /tmp/sops /usr/bin/sops && rm -rf /tmp/*

ENV CONFIG_FILE=/home/buildagent/conf/buildAgent.properties
ENV DOCKER_HOST=tcp://docker:2376

WORKDIR /home/buildagent

USER buildagent

COPY --from=helm --chown=root:root /go/src/bin/helm /usr/bin/helm
COPY --chown=root:root etc/ /etc/
RUN helm plugin install https://github.com/jkroepke/helm-secrets --version v3.8.2
