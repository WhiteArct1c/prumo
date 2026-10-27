# 8. Observabilidade

## O que é

O workload já responde `/metrics`. Falta quem leia isso o tempo todo e quem avise quando o Deployment deixa de ter réplica. O kube-prometheus-stack (chart 92.14.0) instala três programas e os CRDs que os configuram:

- **Prometheus** raspa alvos HTTP no formato OpenMetrics e guarda as séries. Um alvo entra na raspagem quando existe um `ServiceMonitor` cujo selector bate com o Service.
- **Alertmanager** recebe alertas que o Prometheus disparou e agrupa, silencia ou encaminha. Aqui ele só guarda. Não há receiver de Slack ou e-mail.
- **Grafana** lê o Prometheus e desenha painéis. O login não é senha gerada pelo chart: o values aponta `existingSecret: grafana-admin` e as chaves `admin-user` / `admin-password`.

Os CRDs são do prometheus-operator: `ServiceMonitor`, `PrometheusRule`, `Prometheus`. O operator traduz isso em configuração do Prometheus. Você não edita o `prometheus.yml` na mão.

## O que foi desligado

O kind não expõe etcd, scheduler, controller-manager nem kube-proxy para raspagem. Os jobs correspondentes do chart estão desligados. Sem isso o Prometheus fica Degraded por alvos que nunca vão existir neste nó.

`*NilUsesHelmValues: false` nos selectors do Prometheus faz o operator aceitar ServiceMonitor e PrometheusRule de qualquer namespace, não só os que carregam o label do Helm. O monitor do workload mora no namespace `monitoring` e seleciona Services em `referencia-dev` e `referencia-prod`.

## Os três objetos nossos

Em [platform/observability](../../platform/observability), aplicados pela Application `observability` depois do chart:

**ServiceMonitor `referencia`.** Aponta para Services com `app.kubernetes.io/name: referencia` nos dois namespaces. Lê a porta de nome `http`, caminho `/metrics`, a cada 30s. O Prometheus guarda a série `prumo_up`. Com o cluster no ar há três séries: uma do Pod de dev e duas dos Pods de prod, todas com valor `1`.

**PrometheusRule `referencia`.** Uma regra, `ReferenciaForaDoAr`:

```promql
kube_deployment_status_replicas_available{namespace=~"referencia-.+", deployment="referencia"} == 0
```

`for: 1m` exige que a expressão continue verdadeira por um minuto antes de virar alerta. Isso evita disparo num restart de segundos. A métrica vem do kube-state-metrics, que lê a API do Kubernetes, não o `/metrics` do workload. Réplica disponível em zero é "o Deployment não tem Pod Ready". O processo pode estar no ar e ainda assim a probe ter falhado.

**Dashboard `Prumo`.** Um ConfigMap com o label `grafana_dashboard: "1"`. Um sidecar no Pod do Grafana copia esse JSON para `/tmp/dashboards/prumo.json` e recarrega a lista. O `grafana.ini` aponta a página inicial para esse arquivo e redireciona `/` para `/d/prumo/prumo`. Sem isso o Grafana 13 abre a tela "Welcome to Grafana", que não mostra painel nenhum, embora os dashboards existam no menu Dashboards.

Os painéis leem o datasource `prometheus`:

- réplicas disponíveis e `prumo_up`, por namespace
- `ReferenciaForaDoAr`: `ok` enquanto a regra não está `firing`, `disparado` quando está
- pedidos por segundo, a partir de `prumo_requests_total` (o `/metrics` não entra na conta)
- CPU e memória do container `app` nos namespaces `referencia-*`

O datasource Prometheus leva `manageAlerts: true`. A regra do Prometheus passa a aparecer em Alerting, não só dentro do Prometheus. Com o workload no ar ela fica normal, não disparada.

## Onde abrir

Grafana: `http://grafana.localhost:8080`. Usuário `admin`, senha `prumo-dev-admin`. A primeira tela é o dashboard `Prumo`. Os dashboards do próprio Kubernetes (CPU do nó, pods, kubelet) continuam no menu Dashboards, com título `Kubernetes / ...`.

O [roteiro](../demo.md) escala `referencia-prod` para 0 e espera um minuto. O card do alerta vira `disparado` e a regra aparece em Alerting. O selfHeal devolve as 2 réplicas no ciclo seguinte.
