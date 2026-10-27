ifeq ($(OS),Windows_NT)
SHELL := C:/PROGRA~1/Git/bin/bash.exe
.SHELLFLAGS := --noprofile --norc -c
export PATH := $(shell cygpath -u "$(USERPROFILE)/bin"):$(PATH)
HOST_PATH := $(shell pwd -W)
else
HOST_PATH := $(CURDIR)
endif

export KUBECONFIG := $(HOST_PATH)/.cache/kubeconfig
export SOPS_AGE_KEY_FILE := $(HOST_PATH)/keys/dev.agekey
export TF_IN_AUTOMATION := 1

APP_IMAGE ?= $(shell kustomize build deploy/prumo/overlays/dev | awk '/image: / { print $$2; exit }')

.PHONY: up down build status check argocd-password grafana-password check-commit

up: check-commit build
	mkdir -p .cache
	touch .git/git-daemon-export-ok
	terraform -chdir=terraform init
	terraform -chdir=terraform apply -auto-approve \
		-var="repo_host_path=$(HOST_PATH)" \
		-var="app_image=$(APP_IMAGE)" \
		-var="kubeconfig_path=$(KUBECONFIG)"

build:
	docker build -t "$(APP_IMAGE)" apps/prumo
	docker build -t prumo-git:local platform/git

check-commit:
	@git rev-parse --verify HEAD >/dev/null 2>&1 || { echo "O Argo CD so le commit. Crie o primeiro commit e rode make up de novo."; exit 1; }

down:
	-terraform -chdir=terraform destroy -auto-approve \
		-var="repo_host_path=$(HOST_PATH)" \
		-var="app_image=$(APP_IMAGE)" \
		-var="kubeconfig_path=$(KUBECONFIG)"
	-kind delete cluster --name prumo

status:
	kubectl get applications -n argocd
	kubectl get pods -A

check:
	curl -fsS http://dev.prumo.test:8080/healthz
	echo
	curl -fsS http://prod.prumo.test:8080/healthz
	echo

argocd-password:
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo

grafana-password:
	sops -d platform/secrets/grafana-admin.yaml