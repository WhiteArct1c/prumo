# Security

Prumo is a local Kubernetes lab. The point is to try an application on a cluster that already has GitOps, admission policies, TLS, and observability, the same pieces you would take toward a cloud environment. There is no customer and no production data.

The Grafana password and the age key are in the repository on purpose, so a fresh clone can run `make up`. Do not reuse them anywhere else ([ADR 0004](adr/0004-sops-with-a-dev-key.md)).

## What a clone can reach

| Surface | Who can reach it | What they get |
|---|---|---|
| Ports 8080 and 8443 | A process on this machine | Grafana, Argo CD, the sample API |
| The cluster | A privileged Pod | The mounted `.git` |
| This repository | Anyone who clones it | The lab key, the lab password, the manifests |

Those ports bind to `127.0.0.1`. Another host on the LAN does not reach Grafana or Argo CD.

Argo CD reads a `git daemon` inside the cluster, not GitHub ([ADR 0006](adr/0006-argocd-reads-local-git.md)). A commit that only exists on the remote stays out of the cluster until it is in this clone.

## What is already closed

- The kind node publishes 8080 and 8443 on loopback only.
- The node mounts this clone's `.git`, read-only. `terraform.tfstate` and the admin kubeconfig stay on the host.
- Every CI action is pinned to a commit SHA. zizmor, by digest, fails a loose pin, a persisted checkout credential, and triggers such as `pull_request_target`.
- kustomize and kubeconform go through a SHA-256 checksum before they land on `PATH`.
- No checkout leaves the token in `.git/config`. The `release` job receives it only on the last step.
- The `prumo` AppProject may apply only `Namespace`, `Deployment`, `Service`, `Ingress`, `NetworkPolicy`, and `Certificate` in `prumo-dev` and `prumo-prod`. `default` has no source and no destination.

## What stays accepted

**The age key and the Grafana password.** A new clone cannot come up without them. They are in Git on purpose. They belong to this lab only.

**The `platform` AppProject.** It installs CRDs, webhooks, and RBAC, so it is the size of an admin. What it limits is where the manifests come from. Someone who edits `platform/apps` can still create another AppProject. The split protects the workload path, not whoever commits.

**The git daemon.** No authentication, no encryption, read-only, only inside the cluster. It serves a repository that is already public. A Pod can read branches that were never pushed.

**Third-party charts.** Pinned by version. A compromised chart version in the Helm repository lands on the next sync. Pinning a chart digest would live in the same place, with more operational cost.

**The sample image.** The overlay asks for a tag, not a digest. `make up` builds from this tree and loads the image into the node, so the cluster does not need a registry.

## If you run this from a clone

`make up` builds the images on your machine and loads them into kind. You do not need this repository's GHCR package or its Actions runners. The workflow in `.github/workflows` is the CI of this project. It publishes the sample app, not yours.
