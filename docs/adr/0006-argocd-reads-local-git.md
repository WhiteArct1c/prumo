# ADR 0006: Argo CD reads local Git only

## Context

With the repository on GitHub, Argo CD could point at it. The commit where CI writes the new tag would then reach the cluster on its own. That option was tried and dropped.

The problem is who can write to `main` on GitHub. The `release` job has `contents: write`, and a compromised action in that job can commit any manifest, not only the tag. That is what happened to `tj-actions/changed-files` in 2025 and to `aquasecurity/trivy-action` in 2026. If Argo CD read GitHub, that commit would be applied within 30 seconds. A privileged Pod with a hostPath would reach the kind node and, through Docker Desktop, the laptop.

## Decision

Argo CD reads only the `git daemon` that runs inside the cluster. GitHub holds the published source and runs CI. The cluster does not talk to it.

The kind node mounts only this clone's `.git`, read-only. `terraform.tfstate` and `.cache/kubeconfig` live inside the clone directory, outside Git, and never enter the node.

## Consequences

The cluster follows the `HEAD` of this clone, so the branch you have checked out is the branch Argo CD applies. A change reaches the cluster after you commit it here. A change that only exists on the remote stays out until it is in this clone.

Anyone who clones the repository brings up a cluster that reads their own clone, without depending on someone else's GitHub or GHCR.

In a shared environment the source would be a remote with a protected branch and required review, and Applications would stay off the `default` project, in an AppProject with limited destinations and resource kinds.
