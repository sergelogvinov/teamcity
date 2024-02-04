# TeamCity helm chart

Depricated.
Moved to [Helm charts](https://github.com/sergelogvinov/helm-charts) repository.

## Deploy TeamCity to kubernetes

Build you own images and push it to registry

```console
export REGISTRY=my_docker_account
make build push
```

Add custom parameters to file .helm/teamcity/values-dev.yaml
and deploy teamcity to kubernetes

```console
make deploy
```

Very useful helm parameters:

```yaml
ingress:
  enabled: true
  hosts:
    - host: teamcity.local
      paths: ["/"]
  tls:
    - secretName: teamcity.local-tls
      hosts:
        - teamcity.local

server:
   # change server image
  image:
    repository: my_docker_account/teamcity

  # store logs/configs to persistent volumes
  persistentVolume:
    enabled: true
    storageClass: local-path

agent:
  image:
    repository: my_docker_account/teamcity-agent

  # if you have docker build pod
  envs:
    DOCKER_TLS_VERIFY: "1"
    DOCKER_HOST: tcp://docker:2376

  # if docker use tls verification
  extraVolumeMounts:
    - name: tlscerts
      mountPath: /home/buildagent/.docker
  extraVolumes:
    - name: tlscerts
      secret:
        secretName: docker-tls
        defaultMode: 256

# Use postgresql as teamcity database backend
postgresql:
  enabled: true
```
