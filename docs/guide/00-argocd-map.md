# What each name in Argo CD is

The Argo CD UI lists Applications. An Application is not a loose program: it is a package that Argo CD keeps equal to Git or to a Helm chart. `Synced` means the cluster matches the source. `Healthy` means what was installed is up.

The order below is the order traffic and install happen.

**root.** It does not serve the API. It is the list. Terraform creates the `platform` AppProject and this Application, and it reads `platform/apps/`. Each file in that directory becomes one of the rows you see. If `root` goes down, the others stop being updated.

**ingress-nginx.** The HTTP proxy. The browser hits port 8080. This Pod reads the `Host` header (`dev.prumo.test`, `grafana.prumo.test`, `argocd.prumo.test`) and forwards to the right Service. Without it, port 8080 has nothing listening. It is chart 4.15.1, a single controller, listening on port 80 of the kind node. Each request that passes through it becomes a trace, sent to Alloy.

**cert-manager.** Issues TLS certificates. It sees a `Certificate` object and writes a Secret with the certificate. The API does not go through it. The ingress uses the Secret in its `tls` block.

**certs.** Not another program. It is the issuer config: a `ClusterIssuer` named local, which signs a certificate for `*.prumo.test` without a public authority. cert-manager is the program. `certs` is the recipe that says "sign with this lab CA".

**kyverno.** The Kubernetes API doorman. Before a Pod is written, the API server asks Kyverno. If the rule says reject, `kubectl apply` comes back with an error and the Pod never exists. Four processes (admission, background, cleanup, reports) in the `kyverno` namespace.

**policies.** The three rules themselves, not the doorman. `require-limits`, `forbid-latest-tag`, and `require-non-root`. They only apply to the `prumo-dev` and `prumo-prod` namespaces. Kyverno without these rules rejects nothing of ours. The rules without Kyverno are idle YAML.

**kube-prometheus-stack.** The chart that installs Prometheus (stores metrics), Alertmanager (stores alerts), and Grafana (draws). It also installs kube-state-metrics, which turns Deployments and Pods into numbers, and node-exporter, which reads CPU and memory from the node.

**mimir.** Stores metrics for 7 days. Prometheus sends every sample here through `remote_write`. Not a chart: a Deployment of ours in `platform/mimir/`, one process with every Mimir component.

**loki.** Stores logs. One `loki-0` Pod, no gateway, no cache.

**tempo.** Stores traces. One `tempo-0` Pod. It also computes metrics from the spans and writes them to Mimir.

**alloy.** The collector. Reads stdout from every container and writes to Loki. Receives traces from ingress-nginx and forwards them to Tempo. Without it, Loki and Tempo stay up and empty.

**observability.** What is ours on top of that chart: which Service to scrape (the workload `/metrics`), the `PrumoDown` rule, and the `Prumo` dashboard. It stays separate from the chart so our config does not mix with third-party Helm values.

**prumo-dev.** The API, one replica, host `dev.prumo.test`, `ENVIRONMENT=dev`.

**prumo-prod.** The same image, two replicas, host `prod.prumo.test`, `ENVIRONMENT=prod`.
