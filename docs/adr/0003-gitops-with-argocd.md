# ADR 0003: GitOps with Argo CD

## Context

The cluster needs a source of truth that someone else can read. A pipeline that runs `kubectl apply` keeps the truth in the runner history, not in the repository.

## Decision

Argo CD is the only component that applies what lives in [platform/apps/lite](../../platform/apps/lite) or [platform/apps/full](../../platform/apps/full), and in [deploy/prumo](../../deploy/prumo). Sync is automatic. CI builds the image, scans it, and, in the release job, updates the tag in Git. It does not apply a production manifest.

The Git Argo CD reads is a `git daemon` inside the cluster that serves the local clone. `make up` works without GitHub, and a local commit reaches the cluster without a push. Even after the repository is published, the cluster does not read GitHub ([ADR 0006](0006-argocd-reads-local-git.md)).

## Consequences

Nothing enters the cluster without a commit. The Argo CD UI shows what drifted. The cost is running one more controller, and accepting that an uncommitted file is invisible to the cluster.

Platform Applications use the `platform` AppProject. Workload Applications use `prumo`, which may apply only six resource kinds in `prumo-dev` and `prumo-prod`. `default` has no source and no destination. The split separates paths inside the repository. Someone who writes in `platform/apps` can still create another AppProject.
