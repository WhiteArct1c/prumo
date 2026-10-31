# ADR 0005: Monolithic Loki, Tempo, and Mimir on local disk

## Context

kube-prometheus-stack covers recent metrics and alerting. That is the `lite` profile: enough to see replicas, process health, and `PrumoDown`. Logs, traces, and a place for metrics that last longer than Prometheus's 6 hours were still missing. Grafana's LGTM stack covers the three with Loki, Tempo, and Mimir. The production charts for those projects start dozens of Pods, memcached, and object storage. On kind, Docker Desktop memory is the limit (ADR 0001). Those three stay off until `PROFILE=full`.

## Decision

Each store runs as a single process, one replica, on `emptyDir`:

- **Loki** through the `grafana-community/loki` chart in `deploymentMode: Monolithic`, `filesystem` storage, no gateway, no caches, no canary. 72h retention.
- **Tempo** through the `grafana-community/tempo` chart, which is already the single-binary mode. 24h retention. The metrics-generator writes to Mimir.
- **Mimir** without a chart. `mimir-distributed` has no monolithic mode and, in the 3.x series, starts Kafka. This repository ships a Deployment with `-target=all` in [platform/mimir](../../platform/mimir), classic architecture, blocks on `filesystem`. 7-day retention.

The Loki and Tempo charts come from the `grafana-community` repository. Grafana now publishes the open-source charts there. The old `grafana/tempo` chart stopped at Tempo 2.9.

The collector is Grafana Alloy, a Deployment. It reads logs through the Kubernetes API, without mounting `/var/log` on the node. Traces start at ingress-nginx, which already has the OpenTelemetry module. The workload only writes `trace_id` in the log, with no SDK.

## Consequences

The four new Pods request 1 GiB and, with the cluster up, use about 650 MB. Docker Desktop needs 8 GB on `full`. `lite` stays on Prometheus and Grafana and fits in about 4 GB. Grafana's limit is 512Mi on `lite` and 1Gi on `full`: with Loki and Tempo as datasources, opening a trace went over 512Mi and the kernel killed the process.

Restarting the Loki, Tempo, or Mimir Pod wipes what it stored. On kind that barely matters: `make down` deletes the cluster and any PVC with it. In production the three would go to object storage (S3, GCS) in distributed mode, with replicas and cache. Mimir would move to the ingest-storage architecture Grafana recommends from 3.0 on. The classic architecture is marked to leave in a future version. Switching needs the `mimir-distributed` chart and Kafka.

The trace shows only the ingress hop. Time spent inside the workload shows up as that span's duration, with no detail. Instrumenting the workload with the OpenTelemetry SDK would add child spans without changing Alloy or Tempo.
