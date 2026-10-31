# Demo walkthrough

Prerequisite: `make up` finished and `make check` answers `ok` on both hosts.

## 1. Two environments, the same image

Open:

- http://dev.prumo.test:8080
- http://prod.prumo.test:8080

Both texts name the environment. `dev` has one replica. `prod` has two.

```bash
kubectl -n prumo-dev get deploy prumo
kubectl -n prumo-prod get deploy prumo
```

## 2. Git is the source of truth

The Argo CD UI is at http://argocd.prumo.test:8080. User `admin`. Password:

```bash
make argocd-password
```

The Applications are `Synced` and `Healthy`. The path here was a commit, not `kubectl apply` from CI.

## 3. The policy rejects an unsafe manifest

```bash
kubectl apply -f policies/fixtures/invalid-pod.yaml
```

Kyverno rejects the `latest` tag and the missing limits. The workload that is already up passed the same rules.

## 4. The alert fires when the workload goes down

```bash
kubectl -n prumo-prod scale deployment/prumo --replicas=0
```

Wait a little over a minute. In Grafana, at http://grafana.prumo.test:8080, user `admin`, password `prumo-dev-admin`. The home page is the `Prumo` dashboard. The `PrumoDown alert` card shows `firing` on `prumo-prod`. Under Alerting, the same rule appears in the list. The `dev` environment still has its replica up.

Put the environment back to what Git asks for. Argo CD also undoes this on the next selfHeal cycle. To skip the wait:

```bash
kubectl -n prumo-prod scale deployment/prumo --replicas=2
```

If selfHeal already fixed it, the command only confirms the number.

## 5. From the log to the trace

Make a few requests through ingress:

```bash
for i in 1 2 3 4 5; do curl -s http://prod.prumo.test:8080/ >/dev/null; done
```

On the `Prumo` dashboard, the `app container logs` panel shows the new lines ending in `trace_id=...`. Open a line. The `trace_id` field has the `Open in Tempo` link. The trace shows the `HTTP GET prod.prumo.test` span from ingress-nginx, with status and duration.

On the trace, the span logs button goes back to Loki and lists both lines from the same request: ingress-nginx and the workload. `/healthz` lines have no `trace_id`: the kubelet probe does not go through ingress.
