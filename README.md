![Prumo](docs/assets/prumo-logo-no-background.png)

Prumo is a local Kubernetes platform you can stand up on a laptop to see how an application behaves in a cluster that already looks like a cloud one: GitOps, admission policies, TLS, and observability.

| Infrastructure    | ![Kubernetes](https://img.shields.io/badge/Kubernetes-1.32.2-326CE5?logo=kubernetes&logoColor=white) ![Terraform](https://img.shields.io/badge/Terraform-1.17.0-844FBA?logo=terraform&logoColor=white) ![Kustomize](https://img.shields.io/badge/Kustomize-5.8.3-326CE5) ![Argo CD](https://img.shields.io/badge/Argo%20CD-chart%2010.11.6-EF7B4D?logo=argo&logoColor=white) ![ingress-nginx](https://img.shields.io/badge/ingress--nginx-chart%204.15.1-009639?logo=nginx&logoColor=white) |
| ----------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Build and security | ![Python](https://img.shields.io/badge/Python-3.12-3776AB?logo=python&logoColor=white) ![Trivy](https://img.shields.io/badge/Trivy-action%200.35.0-1904DA) ![Kyverno](https://img.shields.io/badge/Kyverno-chart%203.9.2-1E88E5) ![SOPS](https://img.shields.io/badge/SOPS-3.13.3-555555) ![cert-manager](https://img.shields.io/badge/cert--manager-v1.21.3-0A5CBF) |
| Observability     | ![Prometheus](https://img.shields.io/badge/Prometheus-3.5.0-E6522C?logo=prometheus&logoColor=white) ![Grafana](https://img.shields.io/badge/Grafana-13-F46800?logo=grafana&logoColor=white) ![Loki](https://img.shields.io/badge/Loki-chart%2020.0.3-F46800?logo=grafana&logoColor=white) ![Tempo](https://img.shields.io/badge/Tempo-chart%203.2.1-F46800?logo=grafana&logoColor=white) ![Mimir](https://img.shields.io/badge/Mimir-3.2.3-F46800?logo=grafana&logoColor=white) ![Alloy](https://img.shields.io/badge/Alloy-chart%201.14.4-F46800?logo=grafana&logoColor=white) |

`make up` brings up a kind cluster with the delivery path already wired, from commit to `dev` and `prod`. The default observability profile is `lite`: Prometheus, Grafana, and an alert. `make up PROFILE=full` adds Loki, Tempo, Mimir, and Alloy for logs and traces. The API in [`apps/prumo`](apps/prumo) is a 75-line Python example. Another service joins the same cluster by following [guide 9](docs/guide/09-another-application.md).

Terraform creates the cluster and installs Argo CD. From then on, Argo CD is the one that applies, reading Git. GitHub Actions builds the image, runs Trivy, and writes the new tag back to Git. The runner never runs `kubectl apply` on a live cluster, and a file that was not committed never reaches the cluster.

```mermaid
flowchart LR
  push([git push]) --> ci

  subgraph gha["GitHub Actions"]
    ci["validate and kind<br/>fmt, kubeconform, Trivy<br/>prove it on a clean kind"]
    rel["release, main only<br/>image on GHCR<br/>new tag in kustomization"]
    ci --> rel
  end

  rel -- commit --> gh[("GitHub")]
  gh -. git pull .-> git[("local clone")]
  rel --x|never kubectl apply| prod

  subgraph kind["kind cluster"]
    argo["Argo CD"]
    plat["Platform<br/>ingress-nginx, cert-manager<br/>Kyverno, Prometheus"]
    dev["prumo-dev<br/>1 replica"]
    prod["prumo-prod<br/>2 replicas"]
  end

  tf["Terraform"] -. creates the cluster and Argo CD .-> kind

  git -- git daemon --> argo
  argo --> plat
  argo --> dev
  argo --> prod
```

Argo CD reads a `git daemon` inside the cluster that serves this clone's `.git`. Any clone comes up without GitHub, and a local commit reaches the cluster. The cluster does not read GitHub ([ADR 0006](docs/adr/0006-argocd-reads-local-git.md)).

## Bring it up

You need:

- Docker Desktop with **8 GB of memory**, even on `lite`. The kind node alone used about 5.3 GiB on `lite` and 6.5 GiB on `full`. kube-prometheus-stack (Prometheus, Grafana, Alertmanager) is already heavy. Turning off Loki, Tempo, and Mimir saves about 1 GiB, not half the laptop. 4 GB is not enough.
- `make`, `terraform`, `kind`, `kubectl`, `helm`, `kustomize`, `sops`, and `age` on `PATH`
- ports 8080 and 8443 free
- this line in your hosts file (`C:\Windows\System32\drivers\etc\hosts` on Windows, `/etc/hosts` on Linux and macOS):

```text
127.0.0.1 dev.prumo.test prod.prumo.test argocd.prumo.test grafana.prumo.test
```

On Windows, `make` uses the bash that ships with Git for Windows.

```bash
make up              # lite: Prometheus and Grafana, no Loki/Tempo/Mimir
make up PROFILE=full # also Loki, Tempo, Mimir, and Alloy
make observe-full    # add the full stack to a cluster that is already up
make status          # Applications and Pods
make check           # /healthz on dev and prod
make down            # tear it all down, cluster included
```

`make up` returns when Argo CD is up. Applications keep syncing after that. kube-prometheus-stack is the slowest. `lite` is the default: the Grafana home page shows replicas, process health, and the `PrumoDown` alert. Logs, traces, and 7-day metrics need `PROFILE=full`. `lite` is fewer signals, not a small cluster.

Ports 8080 and 8443 bind to `127.0.0.1`. Another machine on the network cannot reach Grafana or Argo CD.

| Address | What it is | Login |
|---|---|---|
| http://dev.prumo.test:8080 | API on `dev`, one replica | |
| http://prod.prumo.test:8080 | API on `prod`, two replicas | |
| http://argocd.prumo.test:8080 | Argo CD | `admin`, password from `make argocd-password` |
| http://grafana.prumo.test:8080 | Grafana, opens on the `Prumo` dashboard | `admin` / `prumo-dev-admin` |

The Grafana password is encrypted with SOPS. The key that opens the file is committed in [`keys/`](keys) so `make up` works on a fresh clone. It is only for this lab ([ADR 0004](docs/adr/0004-sops-with-a-dev-key.md)).

## Walkthrough

The [demo](docs/demo.md) takes about five minutes. It opens both environments, shows the Applications `Synced` in Argo CD, and tries to apply a Pod that Kyverno rejects. Then it scales `prumo-prod` down so the `PrumoDown` alert fires. The log-to-trace step needs `PROFILE=full`.

## What runs in the cluster

Terraform creates one Application, `root`, which reads [`platform/apps/lite`](platform/apps/lite) or [`platform/apps/full`](platform/apps/full). Each file that overlay lists is another Application:

| Application | Profile | What it does |
|---|---|---|
| `ingress-nginx` | both | Takes traffic on port 8080 and routes by `Host`. On `full` it also starts a trace per request |
| `cert-manager` and `certs` | both | Issue the `*.prumo.test` certificate from a local CA |
| `kyverno` and `policies` | both | Reject a Pod with no `limits`, a `latest` tag, or root in `prumo-dev` and `prumo-prod` |
| `kube-prometheus-stack` | both | Prometheus, Alertmanager, and Grafana |
| `observability` | both | ServiceMonitor, `PrumoDown` alert, and the `Prumo` dashboard |
| `prumo-dev` and `prumo-prod` | both | The API, same image in both environments |
| `mimir` | `full` | Keeps metrics for 7 days |
| `loki` | `full` | Keeps logs for 72 hours |
| `tempo` | `full` | Keeps traces for 24 hours |
| `alloy` | `full` | Ships Pod stdout to Loki and ingress traces to Tempo |

The API has no OpenTelemetry SDK. On `full`, the trace starts at ingress-nginx, which forwards the `traceparent` header, and the API writes `trace_id` at the end of each log line. That ID is how Grafana jumps from the log to the trace. [Guide 8](docs/guide/08-observability.md) walks the full path.

## CI

The [`ci`](.github/workflows/ci.yml) workflow runs on push and pull request, except documentation-only changes. It checks Terraform, runs the overlays through `kubeconform`, and fails the image if Trivy finds a HIGH or CRITICAL vulnerability that already has a fix. Then it brings up a clean kind cluster, where Kyverno must reject the invalid Pod and the `dev` overlay must answer `/healthz`.

On `main`, a third job, `release`, runs after the other two pass. If `apps/prumo` changed, it publishes the image to GHCR with that tree hash as the tag and commits the tag in `kustomization.yaml`. Argo CD does the deploy. A clone does not need that image: `make up` builds it and loads it into the node ([guide 6](docs/guide/06-ci.md)).

## Repository map

```text
prumo/
├── apps/prumo/          Sample API and its Dockerfile
├── deploy/prumo/
│   ├── base/            Deployment, Service, Ingress, NetworkPolicy, Certificate
│   └── overlays/        dev (1 replica) and prod (2 replicas)
├── platform/
│   ├── root/            Chart that creates the root Application
│   ├── apps/
│   │   ├── common/      Applications both profiles share
│   │   ├── lite/        default overlay (Prometheus, Grafana)
│   │   └── full/        lite plus Loki, Tempo, Mimir, Alloy
│   ├── lgtm/            Loki, Tempo, Mimir, and Alloy Applications (`full` only)
│   ├── certs/           Local ClusterIssuer
│   ├── mimir/           Monolithic Mimir, no chart
│   ├── observability/
│   │   ├── base/        ServiceMonitor and PrometheusRule
│   │   ├── lite/        dashboard without logs
│   │   └── full/        dashboard with the Loki panel
│   ├── secrets/         Grafana Secret, encrypted with SOPS
│   └── git/             git daemon image that serves this repo to Argo CD
├── policies/            Kyverno ClusterPolicies and the invalid Pod fixture
├── terraform/           The ground: kind cluster, git daemon, Argo CD, Secret
├── keys/                Development age key (read ADR 0004)
└── docs/
    ├── guide/           Study path, one tool at a time
    ├── adr/             Architecture decisions
    ├── security.md      What this lab exposes
    └── demo.md          Five-minute walkthrough
```

## Documentation

[Security](docs/security.md) says what is locked down and what is accepted on purpose.

The guide follows the order each tool shows up on the path: [Argo CD map](docs/guide/00-argocd-map.md), [container](docs/guide/01-container.md), [Kubernetes](docs/guide/02-kubernetes.md), [Kustomize](docs/guide/03-kustomize.md), [Argo CD](docs/guide/04-argocd.md), [Terraform](docs/guide/05-terraform.md), [CI](docs/guide/06-ci.md), [guardrails](docs/guide/07-guardrails.md), [observability](docs/guide/08-observability.md), and [how to put another application on the cluster](docs/guide/09-another-application.md).

The ADRs cover the choices that weigh the most:

- [0001](docs/adr/0001-kind-as-the-cluster.md): the local cluster is kind
- [0002](docs/adr/0002-terraform-only-bootstraps.md): Terraform only bootstraps, Argo CD does the rest
- [0003](docs/adr/0003-gitops-with-argocd.md): GitOps with Argo CD
- [0004](docs/adr/0004-sops-with-a-dev-key.md): SOPS with the development key in the repository
- [0005](docs/adr/0005-monolithic-lgtm.md): Loki, Tempo, and Mimir in monolithic mode, on the `full` profile
- [0006](docs/adr/0006-argocd-reads-local-git.md): Argo CD reads local Git only, never GitHub

## Common problems

| Symptom | Likely cause |
|---|---|
| `make up` stops with "Argo CD only reads commits" | The repository has no commit yet |
| A change does not show up in the cluster | The file was not committed |
| Pods in `monitoring` restarting or `Pending` | Docker Desktop has less than 8 GB. `lite` already used ~5.3 GiB in the kind node |
| `*.prumo.test` addresses do not open | The hosts line is missing, or the port is not 8080 |

## Limits

This is not a managed Kubernetes, a secret vault, or an uptime monitor. Canary, a database, and a second cluster were left out. Loki, Tempo, and Mimir store data in `emptyDir`, so restarting the Pod wipes it. Each ADR says what would change in production.

[MIT](LICENSE) license.

Built with ❤️ and a focus on learning 📚! 🤓
