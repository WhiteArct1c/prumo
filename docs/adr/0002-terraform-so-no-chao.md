# ADR 0002: Terraform só cria o chão

## Contexto

Dá para descrever Deployment, Ingress e Helm release no Terraform. Cada mudança de tag vira apply, estado e um raio de alcance maior do que a mudança pede.

## Decisão

O Terraform cria o cluster, carrega a imagem local, instala o Argo CD, sobe o git daemon e grava o Secret do Grafana. O restante mora no Git e é aplicado pelo Argo CD.

## Consequências

Há uma fronteira clara para explicar numa entrevista: infra muda pouco e tem estado; aplicação muda sempre e tem reconciliação. O estado do Terraform não contém o histórico de deploys do workload.
