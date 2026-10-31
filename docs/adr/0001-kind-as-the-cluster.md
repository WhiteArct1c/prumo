# ADR 0001: The local cluster is kind

## Context

The delivery path needs a real Kubernetes to be shown and reproduced. A managed cluster costs money and hides the bootstrap.

## Decision

The cluster is kind, created by Terraform. Ports 8080 and 8443 on the machine map to ports 80 and 443 on the node. Port 80 on the host stays free on purpose: on Windows it is often taken by HTTP.sys. The same Argo CD Application would point at another cluster if `destination.server` changed. The GitOps contract does not depend on kind.

## Consequences

Anyone with Docker Desktop can bring the environment up. The limit is the machine's memory, not an account. Give Docker Desktop 8 GB. `lite` (Prometheus and Grafana, no Loki/Tempo/Mimir) already used about 5.3 GiB inside the kind node; `full` used about 6.5 GiB. The node image stays on the Kubernetes release pinned for this lab. The release kind currently picks on its own does not finish kubeadm when Docker Desktop is still on cgroup v1. The number is a README shield. Production would still run on managed Kubernetes. This repository does not pretend kind is that environment.
