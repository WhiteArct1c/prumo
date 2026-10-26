# ADR 0001: O cluster local é kind

## Contexto

O caminho de entrega precisa de um Kubernetes de verdade para ser demonstrado e reproduzido. Um cluster gerenciado cobra e esconde o bootstrap.

## Decisão

O cluster é kind, criado pelo Terraform. As portas 8080 e 8443 do computador entram nas portas 80 e 443 do nó. A porta 80 do host fica livre de propósito: no Windows ela costuma estar ocupada pelo HTTP.sys. A mesma Application do Argo CD apontaria para outro cluster se o `destination.server` mudasse. O contrato do GitOps não depende do kind.

## Consequências

Qualquer pessoa com Docker Desktop sobe o ambiente. O limite é a memória da máquina, não uma conta. Produção continuaria em um Kubernetes gerenciado. Este repositório não finge que o kind é esse ambiente.
