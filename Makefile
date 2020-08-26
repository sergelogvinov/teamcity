#

THIS_FILE:=$(lastword $(MAKEFILE_LIST))
BUILD_VCS_BRANCH?=$(shell git branch 2>/dev/null | sed -n '/^\*/s/^\* //p' | sed 's/\//-/g' | sed 's/^(HEAD detached at \(.*\))$$/\1/g')
BUILD_VCS_NUMBER?=$(shell git rev-parse --short=7 HEAD)
CODE_TAG?=$(shell git describe --exact-match --tags 2>/dev/null || git branch 2>/dev/null | sed -n '/^\*/s/^\* //p' | sed 's/\//-/g' | sed 's/^(HEAD detached at \(.*\))$$/\1-$(BUILD_VCS_NUMBER)/g')

REGISTRY?=docker.pkg.github.com/sergelogvinov/teamcity
DOCKER_HOST?=
HELM_PARAMS?=

#

help:
	@awk 'BEGIN {FS = ":.*?## "} /^[0-9a-zA-Z_-]+:.*?## / {sub("\\\\n",sprintf("\n%22c"," "), $$2);printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}' $(MAKEFILE_LIST)


build: ## Build project
	docker build $(BUILDARG) --rm -t local/teamcity:$(CODE_TAG) \
		-f Dockerfile --target=teamcity .

	docker build $(BUILDARG) --rm -t local/teamcity-agent:$(CODE_TAG) \
		-f Dockerfile --target=teamcity-agent .


run: ## Run locally
	docker rm -f teamcity 2>/dev/null ||:
	docker run --rm -ti --name teamcity -h local \
		-e DOCKER_HOST=$(DOCKER_HOST) \
		local/teamcity:$(CODE_TAG)


push: ## Push image to registry
	docker tag local/teamcity:$(CODE_TAG) $(REGISTRY)/teamcity:$(CODE_TAG)
	docker push $(REGISTRY)/teamcity:$(CODE_TAG)

	docker tag local/teamcity:$(CODE_TAG) $(REGISTRY)/teamcity-agent:$(CODE_TAG)
	docker push $(REGISTRY)/teamcity-agent:$(CODE_TAG)

