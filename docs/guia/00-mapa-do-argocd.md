# O que cada nome no Argo CD é

A tela do Argo CD lista Applications. Uma Application não é um programa solto: é um pacote que o Argo CD mantém igual ao Git ou a um chart Helm. `Synced` quer dizer que o cluster está igual à origem. `Healthy` quer dizer que o que foi instalado está de pé.

A ordem abaixo é a ordem em que o tráfego e a instalação acontecem.

**root.** Não serve a API. É a lista. O Terraform cria só esta Application, e ela lê `platform/apps/`. Cada arquivo dessa pasta vira uma das linhas que você vê. Se a `root` cair, as outras deixam de ser atualizadas.

**ingress-nginx.** O proxy HTTP. O navegador chega na porta 8080. Este Pod lê o cabeçalho `Host` (`dev.prumo.test`, `grafana.prumo.test`, `argocd.prumo.test`) e encaminha para o Service certo. Sem ele, a porta 8080 não tem quem responda. É o chart 4.15.1, um controlador só, escutando a porta 80 do nó kind. Cada pedido que passa por ele vira um trace, enviado ao Alloy.

**cert-manager.** Emite certificados TLS. Ele vê um objeto `Certificate` e grava um Secret com o certificado. A API não passa por ele. Quem usa o Secret é o ingress, no bloco `tls`.

**certs.** Não é outro programa. É a configuração do emissor: um `ClusterIssuer` chamado de local, que assina certificado para `*.prumo.test` sem uma autoridade pública. O cert-manager é o programa. `certs` é a receita que diz "assine com esta CA de laboratório".

**kyverno.** O porteiro da API do Kubernetes. Antes de um Pod ser gravado, o API server pergunta ao Kyverno. Se a regra manda recusar, o `kubectl apply` volta com erro e o Pod não existe. São quatro processos (admission, background, cleanup, reports) no namespace `kyverno`.

**policies.** As três regras em si, não o porteiro. `exigir-limits`, `proibir-tag-latest` e `exigir-non-root`. Só valem para os namespaces `prumo-dev` e `prumo-prod`. O Kyverno sem estas regras não recusa nada nosso. As regras sem o Kyverno são YAML parado.

**kube-prometheus-stack.** O chart que instala Prometheus (guarda métricas), Alertmanager (guarda alertas) e Grafana (desenha). Também instala o kube-state-metrics, que traduz Deployment e Pod em número, e o node-exporter, que lê CPU e memória do nó.

**mimir.** Guarda métricas por 7 dias. O Prometheus envia cada amostra para cá por `remote_write`. Não é chart: é um Deployment nosso em `platform/mimir/`, um processo com todos os componentes do Mimir.

**loki.** Guarda logs. Um Pod `loki-0`, sem gateway nem cache.

**tempo.** Guarda traces. Um Pod `tempo-0`. Também calcula métricas a partir dos spans e grava no Mimir.

**alloy.** O coletor. Lê o stdout de todos os containers e grava no Loki. Recebe os traces do ingress-nginx e repassa ao Tempo. Sem ele, Loki e Tempo ficam no ar e vazios.

**observability.** O que é nosso em cima desse chart: qual Service raspar (`/metrics` do workload), a regra `PrumoForaDoAr` e o dashboard `Prumo`. Fica separado do chart para não misturar configuração nossa com valores do Helm de terceiro.

**prumo-dev.** A API, uma réplica, host `dev.prumo.test`, variável `ENVIRONMENT=dev`.

**prumo-prod.** A mesma imagem, duas réplicas, host `prod.prumo.test`, variável `ENVIRONMENT=prod`.
