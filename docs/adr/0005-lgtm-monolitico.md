# ADR 0005: Loki, Tempo e Mimir monolíticos, em disco local

## Contexto

O kube-prometheus-stack cobre métricas recentes e alerta. Faltam logs, traces e um lugar para métricas que dure mais que as 6h do Prometheus. A stack LGTM da Grafana resolve os três com Loki, Tempo e Mimir. Os charts de produção desses projetos sobem dezenas de Pods, cache em memcached e object storage. No kind, a memória do Docker Desktop é o limite (ADR 0001).

## Decisão

Cada banco roda como um processo só, uma réplica, com `emptyDir`:

- **Loki** pelo chart `grafana-community/loki` em `deploymentMode: Monolithic`, armazenamento `filesystem`, sem gateway, sem caches e sem canary. Retenção de 72h.
- **Tempo** pelo chart `grafana-community/tempo`, que já é o modo de binário único. Retenção de 24h. O metrics-generator grava no Mimir.
- **Mimir** sem chart. O `mimir-distributed` não tem modo monolítico e, na série 3.x, sobe Kafka. O repositório traz um Deployment com `-target=all` em [platform/mimir](../../platform/mimir), na arquitetura clássica e com blocos em `filesystem`. Retenção de 7 dias.

Os charts de Loki e Tempo vêm do repositório `grafana-community`. A Grafana passou a publicar ali os charts de código aberto. O `grafana/tempo` antigo parou no Tempo 2.9.

O coletor é o Grafana Alloy, um Deployment. Ele lê logs pela API do Kubernetes, sem montar `/var/log` do nó. Os traces nascem no ingress-nginx, que já tem o módulo de OpenTelemetry. O workload só escreve o `trace_id` no log, sem SDK.

## Consequências

Os quatro Pods novos pedem 1 GiB em requests e, com o cluster no ar, usam perto de 650 MB. O Docker Desktop passa a precisar de 8 GB. O Grafana subiu o limite de 512Mi para 1Gi: com Loki e Tempo como datasources, abrir um trace passava do limite e o kernel matava o processo.

Reiniciar o Pod de Loki, Tempo ou Mimir apaga o que ele guardou. No kind isso pouco muda: `make down` apaga o cluster e qualquer PVC junto. Em produção os três iriam para object storage (S3, GCS) no modo distribuído, com réplicas e cache. O Mimir iria para a arquitetura de ingest storage, que a Grafana recomenda a partir da 3.0. A arquitetura clássica está marcada para sair numa versão futura. Trocar exige o chart `mimir-distributed` e um Kafka.

O trace mostra só o salto do ingress. O tempo gasto dentro do workload aparece como a duração desse span, sem detalhe. Instrumentar o workload com o SDK de OpenTelemetry adicionaria spans filhos sem mudar nada no Alloy nem no Tempo.
