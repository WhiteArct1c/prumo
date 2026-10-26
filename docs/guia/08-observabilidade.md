# 8. Observabilidade

Subir o Pod não termina o deploy. Alguém precisa saber, sem abrir o container, se ele está atendendo.

O kube-prometheus-stack instala Prometheus, Alertmanager e Grafana. Os componentes do control plane que o kind não expõe (etcd, scheduler, controller-manager, kube-proxy) ficam desligados. O Prometheus descobre qualquer ServiceMonitor e qualquer PrometheusRule, sem exigir o label do Helm.

Três objetos em [platform/observability](../../platform/observability) fecham o ciclo:

- o ServiceMonitor raspa `/metrics` dos Services `referencia` em `dev` e `prod`
- o dashboard `Prumo` lê `prumo_up` e as réplicas disponíveis
- a regra `ReferenciaForaDoAr` dispara quando `kube_deployment_status_replicas_available` fica em zero por um minuto

O Grafana abre em `http://grafana.localhost:8080`. O usuário é `admin`. A senha está no Secret cifrado: `make grafana-password`.

O roteiro para ver o alerta está em [docs/demo.md](../demo.md).
