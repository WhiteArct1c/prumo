# 4. Argo CD

## O que é

O Argo CD é um controlador que roda dentro do cluster. O objeto dele se chama `Application` (grupo `argoproj.io`). Cada Application tem:

- `source`: de onde ler (URL do Git ou repositório Helm, revisão, path ou chart)
- `destination`: em qual cluster e namespace aplicar
- `syncPolicy`: se aplica sozinho, se apaga o que saiu do Git (`prune`) e se desfaz mudança feita fora do Git (`selfHeal`)

A cada 30 segundos (`timeout.reconciliation` em [platform/argocd-values.yaml](../../platform/argocd-values.yaml)) ele lê o Git, gera o YAML (Kustomize ou Helm) e compara com o que está na API. `Synced` significa que o vivo bate com o desejado. `Healthy` significa que os objetos estão prontos (Deployment com réplicas disponíveis, por exemplo). Os dois são independentes: dá para estar Synced e Degraded.

`kubectl apply` a partir de um laptop não entra nesse ciclo. No minuto seguinte o cluster pode divergir e ninguém fica sabendo. Com selfHeal, um `kubectl scale` volta ao número que está no Git no próximo ciclo.

## App-of-apps

O Terraform instala o Helm chart do Argo CD (versão 10.11.6) e uma única Application, a `root`, pelo chart local [platform/root](../../platform/root). A `root` aponta para o diretório [platform/apps](../../platform/apps). Cada arquivo ali é outra Application. A `root` não contém o Deployment do workload. Ela contém a lista do que deve existir.

| Application | Origem | Wave | O que instala |
|---|---|---|---|
| `ingress-nginx` | chart 4.15.1 | -3 | o proxy que publica os hosts |
| `kyverno` | chart 3.9.2 | -2 | o admission webhook |
| `cert-manager` | chart v1.21.3 | -2 | o emissor de certificado |
| `policies` | Git, `policies/` | 0 | as três ClusterPolicies |
| `certs` | Git, `platform/certs/` | 1 | o ClusterIssuer local |
| `kube-prometheus-stack` | chart 92.14.0 | 1 | Prometheus, Grafana, Alertmanager |
| `observability` | Git, `platform/observability/` | 2 | ServiceMonitor, regra e dashboard |
| `referencia-dev` | Git, overlay dev | 3 | o workload |
| `referencia-prod` | Git, overlay prod | 3 | o workload |

A annotation `argocd.argoproj.io/sync-wave` ordena a sincronização. Wave menor aplica antes. O ingress existe antes de qualquer Ingress de aplicação. As políticas existem antes dos Pods do workload. A wave espera a Application anterior ficar saudável, não só aplicada.

Charts de terceiro vêm de repositórios Helm públicos. O que é nosso usa `repoURL: git://git.git.svc.cluster.local/prumo` e `targetRevision: HEAD`.

## O Git que o Argo CD lê

Não há GitHub dentro do cluster. Um Pod no namespace `git` roda `git daemon` na porta 9418, imagem `prumo-git:local`. O volume é um hostPath `/git/prumo`, montado somente leitura a partir da pasta deste repositório no nó kind. O daemon exporta esse repositório não-bare.

Consequência prática: o Argo CD clona commits. Arquivo salvo e não commitado não existe para ele. `git status` limpo e `git log` com o commit novo são o que a próxima reconciliação enxerga.

Dex e notifications estão desligados. O servidor do Argo CD escuta HTTP (`server.insecure: true`) atrás do mesmo ingress, no host `argocd.localhost`, porta 8080 da sua máquina. Usuário `admin`. A senha é gerada na instalação e fica no Secret `argocd-initial-admin-secret`, no namespace `argocd`. `make argocd-password` imprime esse valor. Ela muda se o cluster for recriado.

## Prune, selfHeal e diff

`prune: true` apaga do cluster um objeto que saiu do Git. Remover um arquivo do overlay e commitar remove o objeto. Sem prune, o objeto órfão fica.

`selfHeal: true` reaplica o que alguém mudou com `kubectl edit` ou `kubectl scale`.

`ServerSideApply=true` manda o apply pelo field manager da API, em vez do merge de três vias do `kubectl apply` clássico. No Kyverno isso ainda não basta para os CRDs: o chart e o apiserver divergem em campos preenchidos pelo próprio Kubernetes. A Application `kyverno` usa `argocd.argoproj.io/compare-options: ServerSideDiff=true` para o diff usar a mesma comparação do `kubectl diff`. As ClusterPolicies ignoram `.status` e os defaults que o controlador do Kyverno grava (`admission`, `emitWarning`, `skipBackgroundRequests`). Sem isso a interface mostra OutOfSync com o cluster já igual ao Git.
