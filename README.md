# Prumo

Portfólio de entrega. O Prumo mostra o caminho que um time usa para levar um serviço de um commit até os ambientes `dev` e `prod`. Não é um produto novo. A API em `apps/prumo` existe para esse caminho ter o que carregar.

Terraform cria o cluster e o Argo CD. O Argo CD aplica o que está no Git. GitHub Actions constrói a imagem, o Trivy escaneia, e o workflow de release grava a tag nova no Git. O runner não executa `kubectl apply` em produção.

```mermaid
flowchart LR
  commit[Commit] --> ci[GitHub Actions]
  ci --> scan[Trivy]
  scan --> ghcr[Imagem no GHCR]
  ci --> git[Tag nova no Git]
  git --> argo[Argo CD]
  tf[Terraform] --> cluster[Cluster kind]
  tf --> argo
  argo --> dev[prumo-dev]
  argo --> prod[prumo-prod]
```

## O que sobe

Depois de `make up`, na mesma máquina:

| Endereço | O que é |
|---|---|
| http://dev.prumo.test:8080 | Workload, uma réplica |
| http://prod.prumo.test:8080 | Workload, duas réplicas |
| http://argocd.prumo.test:8080 | Argo CD. Usuário `admin`. A senha é gerada na instalação: `make argocd-password` |
| http://grafana.prumo.test:8080 | Grafana. Usuário `admin`, senha `prumo-dev-admin` |

O Grafana usa a senha cifrada em `platform/secrets/grafana-admin.yaml`. A chave que abre esse arquivo está no repositório de propósito. Leia [docs/adr/0004-sops-com-chave-de-desenvolvimento.md](docs/adr/0004-sops-com-chave-de-desenvolvimento.md).

## Pré-requisitos

- Docker Desktop em execução, com pelo menos 6 GB de memória para o kube-prometheus-stack
- `make`, `terraform`, `kind`, `kubectl`, `helm`, `kustomize`, `sops` e `age` no `PATH`
- As portas 8080 e 8443 livres. O HTTP fica na porta 8080. O certificado local também existe na 8443, e o ingress não redireciona o HTTP para lá.
- Esta linha em `C:\Windows\System32\drivers\etc\hosts`: `127.0.0.1 dev.prumo.test prod.prumo.test argocd.prumo.test grafana.prumo.test`

No Windows, o `make` deste repositório usa o bash que vem com o Git for Windows.

## Subir e derrubar

```bash
make up
make check
make status
make down
```

`make up` constrói a imagem, cria o cluster e espera o Argo CD existir. As Applications seguem sincronizando depois que o comando termina. `make status` mostra o que ainda não ficou `Healthy`. A primeira sincronização do kube-prometheus-stack é a mais demorada.

O Argo CD lê commits. Um arquivo salvo e não commitado não entra no cluster.

## Como o repositório está dividido

- `terraform/` cria o cluster, o git daemon, o Argo CD e o Secret do Grafana
- `platform/apps/` é a lista de Applications que o Argo CD reconcilia
- `platform/certs/` é o emissor de certificado local
- `platform/observability/` é o ServiceMonitor, o alerta e o dashboard
- `deploy/prumo/` é a base e os overlays `dev` e `prod`
- `policies/` são as regras do Kyverno para os namespaces do workload
- `apps/prumo/` é o workload de referência
- `docs/guia/` explica cada ferramenta. O [mapa do Argo CD](docs/guia/00-mapa-do-argocd.md) diz o que é cada nome da interface. O [guia 9](docs/guia/09-outra-aplicacao.md) descreve como colocar outra API no mesmo kind
- `docs/adr/` registra as decisões
- `docs/demo.md` é o roteiro de cinco minutos

## O que isto não é

Não substitui um Kubernetes gerenciado, um cofre de segredos nem um monitor de uptime. Canary, banco e segundo cluster ficam de fora. O valor do repositório é o caminho, reproduzível com `make up`, e a separação entre quem constrói a imagem e quem aplica no cluster.
