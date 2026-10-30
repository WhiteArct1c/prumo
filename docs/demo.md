# Roteiro de demonstração

Pré-requisito: `make up` terminou e `make check` responde `ok` nos dois hosts.

## 1. Dois ambientes, a mesma imagem

Abra:

- http://dev.prumo.test:8080
- http://prod.prumo.test:8080

Os dois textos citam o ambiente. `dev` tem uma réplica. `prod` tem duas.

```bash
kubectl -n prumo-dev get deploy prumo
kubectl -n prumo-prod get deploy prumo
```

## 2. O Git é a fonte da verdade

A interface do Argo CD está em http://argocd.prumo.test:8080. Usuário `admin`. Senha:

```bash
make argocd-password
```

As Applications estão `Synced` e `Healthy`. O caminho até aqui foi commit, não `kubectl apply` a partir do CI.

## 3. A política recusa um manifesto inseguro

```bash
kubectl apply -f policies/fixtures/pod-invalido.yaml
```

O Kyverno recusa a tag `latest` e a ausência de limites. O workload que já está no ar passou pelas mesmas regras.

## 4. O alerta dispara quando o workload sai do ar

```bash
kubectl -n prumo-prod scale deployment/prumo --replicas=0
```

Espere pouco mais de um minuto. No Grafana, em http://grafana.prumo.test:8080, usuário `admin`, senha `prumo-dev-admin`. A página inicial é o dashboard `Prumo`. O card `Alerta PrumoForaDoAr` mostra `disparado` em `prumo-prod`. Em Alerting, a mesma regra aparece na lista. O ambiente `dev` continua com a réplica no ar.

Volte o ambiente ao que o Git pede. O Argo CD também desfaz isso no próximo ciclo de selfHeal. Para não esperar:

```bash
kubectl -n prumo-prod scale deployment/prumo --replicas=2
```

Se o selfHeal já tiver corrigido, o comando só confirma o número.

## 5. Do log ao trace

Faça alguns pedidos pelo ingress:

```bash
for i in 1 2 3 4 5; do curl -s http://prod.prumo.test:8080/ >/dev/null; done
```

No dashboard `Prumo`, o painel `Logs do container app` mostra as linhas novas terminando em `trace_id=...`. Abra uma linha. O campo `trace_id` tem o link `Abrir no Tempo`. O trace mostra o span `HTTP GET prod.prumo.test` do ingress-nginx, com status e duração.

No trace, o botão de logs do span volta ao Loki e lista as duas linhas do mesmo pedido: a do ingress-nginx e a do workload. As linhas de `/healthz` não têm `trace_id`: a probe do kubelet não passa pelo ingress.
