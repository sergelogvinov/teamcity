# Teamcity

## TL;DR;

```console
$ helm repo add sergelogvinov https://helm-charts.sinextra.dev
$ helm install sergelogvinov/teamcity
```

## Introduction

This chart bootstraps the Teamcity deployment on a [Kubernetes](http://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Installing the Chart

To install the chart with the release name `private-teamcity`:

```console
$ helm install sergelogvinov/teamcity --name private-teamcity
```

The command deploys teamcity on the Kubernetes cluster in the default configuration. The [configuration](#configuration) section lists the parameters that can be configured during installation.

## Uninstalling the Chart

To uninstall/delete the `private-teamcity` deployment:

```console
$ helm delete private-teamcity
```

The command removes all the Kubernetes components associated with the chart and deletes the release.

## Configuration

The following table lists the configurable parameters of the teamcity chart and their default values.

