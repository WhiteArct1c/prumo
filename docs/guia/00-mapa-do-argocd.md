# O que cada nome no Argo CD é

A tela do Argo CD lista Applications. Uma Application não é um programa solto: é um pacote que o Argo CD mantém igual ao Git ou a um chart Helm. `Synced` quer dizer que o cluster está igual à origem. `Healthy` quer dizer que o que foi instalado está de pé.

A ordem abaixo é a ordem em que o tráfego e a instalação acontecem.

**root.** Não serve a API. É a lista. O Terraform cria só esta Application, e ela lê `platform/apps/`. Cada arquivo dessa pasta vira uma das linhas que você vê. Se a `root` cair, as outras deixam de ser atualizadas.

**ingress-nginx.** O proxy HTTP. O navegador chega em `localhost:8080`. Este Pod lê o cabeçalho `Host` (`referencia.dev.localhost`, `grafana.localhost`, `argocd.localhost`) e encaminha para o Service certo. Sem ele, a porta 8080 não tem quem responda. É o chart 4.15.1, um controlador só, escutando a porta 80 do nó kind.

**cert-manager.** Emite certificados TLS. Ele vê um objeto `Certificate` e grava um Secret com o certificado. A API não passa por ele. Quem usa o Secret é o ingress, no bloco `tls`.

**certs.** Não é outro programa. É a configuração do emissor: um `ClusterIssuer` chamado de local, que assina certificado para `*.localhost` sem uma autoridade pública. O cert-manager é o programa. `certs` é a receita que diz "assine com esta CA de laboratório".

**kyverno.** O porteiro da API do Kubernetes. Antes de um Pod ser gravado, o API server pergunta ao Kyverno. Se a regra manda recusar, o `kubectl apply` volta com erro e o Pod não existe. São quatro processos (admission, background, cleanup, reports) no namespace `kyverno`.

**policies.** As três regras em si, não o porteiro. `exigir-limits`, `proibir-tag-latest` e `exigir-non-root`. Só valem para os namespaces `referencia-dev` e `referencia-prod`. O Kyverno sem estas regras não recusa nada nosso. As regras sem o Kyverno são YAML parado.

**kube-prometheus-stack.** O chart que instala Prometheus (guarda métricas), Alertmanager (guarda alertas) e Grafana (desenha). Também instala o kube-state-metrics, que traduz Deployment e Pod em número, e o node-exporter, que lê CPU e memória do nó.

**observability.** O que é nosso em cima desse chart: qual Service raspar (`/metrics` do workload), a regra `ReferenciaForaDoAr` e o dashboard `Prumo`. Fica separado do chart para não misturar configuração nossa com valores do Helm de terceiro.

**referencia-dev.** A API, uma réplica, host `referencia.dev.localhost`, variável `ENVIRONMENT=dev`.

**referencia-prod.** A mesma imagem, duas réplicas, host `referencia.prod.localhost`, variável `ENVIRONMENT=prod`.
