# Roteiro de demonstração

Pré-requisito: `make up` terminou e `make check` responde `ok` nos dois hosts.

## 1. Dois ambientes, a mesma imagem

Abra:

- http://referencia.dev.localhost:8080
- http://referencia.prod.localhost:8080

Os dois textos citam o ambiente. `dev` tem uma réplica. `prod` tem duas.

```bash
kubectl -n referencia-dev get deploy referencia
kubectl -n referencia-prod get deploy referencia
```

## 2. O Git é a fonte da verdade

A interface do Argo CD está em http://argocd.localhost:8080. Usuário `admin`. Senha:

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
kubectl -n referencia-prod scale deployment/referencia --replicas=0
```

Espere pouco mais de um minuto. No Grafana, em http://grafana.localhost:8080, usuário `admin`, a senha sai de:

```bash
make grafana-password
```

Abra Alerting. A regra `ReferenciaForaDoAr` fica ativa para `referencia-prod`. O ambiente `dev` continua com a réplica no ar.

Volte o ambiente ao que o Git pede. O Argo CD também desfaz isso no próximo ciclo de selfHeal. Para não esperar:

```bash
kubectl -n referencia-prod scale deployment/referencia --replicas=2
```

Se o selfHeal já tiver corrigido, o comando só confirma o número.
