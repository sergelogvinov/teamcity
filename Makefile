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
	docker rm -f teamcity psql 2>/dev/null ||:

	docker run -d --name psql -e POSTGRES_PASSWORD=teamcity -e POSTGRES_DB=teamcity -e POSTGRES_USER=teamcity \
		-p 5432:5432 -p 8111:8111 postgres:11.8 >/dev/null
	docker exec -i psql sh -c "while ! psql -h 127.0.0.1 -U teamcity teamcity -tAc 'SELECT 1;' >/dev/null 2>/dev/null; do sleep 1; done"

	docker run -ti --rm --name teamcity --network=container:psql \
		local/teamcity:$(CODE_TAG)


push: ## Push image to registry
	docker tag local/teamcity:$(CODE_TAG) $(REGISTRY)/teamcity:$(CODE_TAG)
	docker push $(REGISTRY)/teamcity:$(CODE_TAG)

	docker tag local/teamcity:$(CODE_TAG) $(REGISTRY)/teamcity-agent:$(CODE_TAG)
	docker push $(REGISTRY)/teamcity-agent:$(CODE_TAG)


deploy:
	touch .helm/teamcity/values-dev.yaml
	helm upgrade -i $(HELM_PARAMS) -f .helm/teamcity/values-dev.yaml \
		--history-max 3 \
		--set server.image.tag=$(CODE_TAG) \
		teamcity .helm/teamcity/

