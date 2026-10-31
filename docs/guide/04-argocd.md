# 4. Argo CD

## What it is

Argo CD is a controller that runs inside the cluster. Its object is called `Application` (group `argoproj.io`). Each Application has:

- `source`: where to read from (Git URL or Helm repository, revision, path or chart)
- `destination`: which cluster and namespace to apply to
- `syncPolicy`: whether it applies on its own, whether it deletes what left Git (`prune`), and whether it undoes a change made outside Git (`selfHeal`)

Every 30 seconds (`timeout.reconciliation` in [platform/argocd-values.yaml](../../platform/argocd-values.yaml)) it reads Git, generates the YAML (Kustomize or Helm), and compares it with what is in the API. `Synced` means live matches desired. `Healthy` means the objects are ready (a Deployment with available replicas, for example). The two are independent: you can be Synced and Degraded.

`kubectl apply` from a laptop is not in that loop. A minute later the cluster can drift and nobody hears about it. With selfHeal, a `kubectl scale` returns to the number in Git on the next cycle.

## App-of-apps

Terraform installs the Argo CD Helm chart (version 10.11.6) and a single Application, `root`, from the local chart [platform/root](../../platform/root). `root` points at [platform/apps/lite](../../platform/apps/lite) or [platform/apps/full](../../platform/apps/full). Each file that overlay lists is another Application. `root` does not hold the workload Deployment. It holds the list of what should exist. `mimir`, `loki`, `tempo`, and `alloy` are only on `full`.

| Application | Source | Wave | What it installs |
|---|---|---|---|
| `ingress-nginx` | chart 4.15.1 | -3 | the proxy that publishes the hosts |
| `kyverno` | chart 3.9.2 | -2 | the admission webhook |
| `cert-manager` | chart v1.21.3 | -2 | the certificate issuer |
| `policies` | Git, `policies/` | 0 | the three ClusterPolicies |
| `certs` | Git, `platform/certs/` | 1 | the local ClusterIssuer |
| `kube-prometheus-stack` | chart 92.14.0 | 1 | Prometheus, Grafana, Alertmanager |
| `observability` | Git, `platform/observability/lite` or `full` | 2 | ServiceMonitor, rule, and dashboard |
| `prumo-dev` | Git, dev overlay | 3 | the workload |
| `prumo-prod` | Git, prod overlay | 3 | the workload |
| `mimir`, `loki`, `tempo`, `alloy` | `full` only | 1 | the LGTM stores and the collector |

The `argocd.argoproj.io/sync-wave` annotation orders the sync. A lower wave applies first. Ingress exists before any application Ingress. The policies exist before the workload Pods. A wave waits for the previous Application to become healthy, not only applied.

Third-party charts come from public Helm repositories. What is ours uses `repoURL: git://git.git.svc.cluster.local/prumo` and `targetRevision: HEAD`.

## Projects

Every Application belongs to an AppProject, which says where it may read from, where it may apply, and which kinds it may create.

| Project | Who uses it | What it allows |
|---|---|---|
| `platform` | `root` and the platform Applications | the git daemon and the six chart repositories, any namespace, any kind |
| `prumo` | `prumo-dev` and `prumo-prod` | only the git daemon, only the two namespaces, only `Namespace`, `Deployment`, `Service`, `Ingress`, `NetworkPolicy`, and `Certificate` |
| `default` | none | nothing |

`platform` lives in the root chart, in [platform/root/templates/project.yaml](../../platform/root/templates/project.yaml), because `root` needs it to exist. `prumo` and the locked `default` live in `platform/apps`, on wave -4.

In practice, someone who edits `deploy/prumo` cannot create a ClusterRoleBinding, a DaemonSet, or a Pod in `kube-system` through this path. Argo CD rejects the sync before it reaches the API. Someone who edits `platform/apps` still has admin power, because a file there can create another AppProject. The project splits paths inside the repository. It does not protect against whoever writes to the repository.

## The Git Argo CD reads

There is no GitHub inside the cluster. A Pod in the `git` namespace runs `git daemon` on port 9418, image `prumo-git:local`. The volume is a hostPath `/git/prumo` on the kind node, which receives only this repository's `.git`, read-only. The daemon serves the `HEAD` of that `.git`, the branch that is checked out in the clone. The cluster does not read GitHub ([ADR 0006](../adr/0006-argocd-reads-local-git.md)).

Practical consequence: Argo CD clones commits. A file that was saved and not committed does not exist for it. A clean `git status` and a `git log` with the new commit are what the next reconciliation sees.

Dex and notifications are off. The Argo CD server listens on HTTP (`server.insecure: true`) behind the same ingress, host `argocd.prumo.test`, port 8080 on your machine. User `admin`. The password is generated at install time and lives in the `argocd-initial-admin-secret` Secret, in the `argocd` namespace. `make argocd-password` prints that value. It changes if the cluster is recreated.

## Prune, selfHeal, and diff

`prune: true` deletes from the cluster an object that left Git. Removing a file from the overlay and committing removes the object. Without prune, the orphan stays.

`selfHeal: true` reapplies what someone changed with `kubectl edit` or `kubectl scale`.

`ServerSideApply=true` sends the apply through the API field manager, instead of classic `kubectl apply` three-way merge. For Kyverno that is still not enough for the CRDs: the chart and the apiserver drift on fields Kubernetes itself fills. The `kyverno` Application uses `argocd.argoproj.io/compare-options: ServerSideDiff=true` so the diff uses the same comparison as `kubectl diff`. The ClusterPolicies ignore `.status` and the defaults the Kyverno controller writes (`admission`, `emitWarning`, `skipBackgroundRequests`). Without that, the UI shows OutOfSync while the cluster already matches Git.
