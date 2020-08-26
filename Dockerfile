#
FROM jetbrains/teamcity-server AS teamcity

RUN curl -LfsSo /opt/teamcity/webapps/ROOT/WEB-INF/lib/postgresql-42.2.16.jar https://jdbc.postgresql.org/download/postgresql-42.2.16.jar && \
    echo "6d02942406e92153c6675617dade3524 /opt/teamcity/webapps/ROOT/WEB-INF/lib/postgresql-42.2.16.jar" | md5sum -c -

RUN install -o tcuser -g tcuser -d /data -d /data/logs -d /data/datadir -d /data/temp

ENV TEAMCITY_DATA_PATH=/data/datadir TEAMCITY_LOGS_PATH=/data/logs TEAMCITY_LOGS=/data/logs TEAMCITY_TEMP=/data/temp

# USER tcuser
WORKDIR /opt/teamcity
CMD ["/opt/teamcity/bin/teamcity-server.sh","run"]

#
FROM jetbrains/teamcity-agent  AS teamcity-agent

USER root
RUN apt-get update && apt-get install -y software-properties-common vim curl wget git make zip rsync && \
    apt-add-repository ppa:ansible/ansible && apt-get update -y && \
    apt-get install -y ansible && \
    apt-get install -y python-pip python-netaddr python-boto python-jmespath && \
    pip install dopy && \
    apt-get autoremove -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*

RUN mkdir -p /home/buildagent/conf /home/buildagent/.ansible && \
    chown -R buildagent.buildagent /opt/buildagent /home/buildagent /services

RUN wget https://dl.k8s.io/v1.18.8/kubernetes-client-linux-amd64.tar.gz -O /tmp/kubernetes-client-linux-amd64.tar.gz && \
    cd /tmp && tar -xzf /tmp/kubernetes-client-linux-amd64.tar.gz && mv kubernetes/client/bin/kubectl /usr/bin/kubectl && \
    wget https://get.helm.sh/helm-v3.3.0-linux-amd64.tar.gz -O /tmp/helm.tar.gz && \
    cd /tmp && tar -xzf /tmp/helm.tar.gz && mv linux-amd64/helm /usr/bin/helm && rm -rf /tmp/*

ENV CONFIG_FILE=/home/buildagent/conf/buildAgent.properties
ENV DOCKER_HOST=tcp://docker:2376

WORKDIR /home/buildagent

USER buildagent
COPY --chown=root:root             etc/ /etc/

RUN helm repo add stable https://kubernetes-charts.storage.googleapis.com && \
    helm repo add incubator https://kubernetes-charts-incubator.storage.googleapis.com
