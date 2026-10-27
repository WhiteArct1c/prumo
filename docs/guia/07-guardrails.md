# 7. Guardrails

Três mecanismos diferentes, com papéis que não se misturam.

O Kyverno decide se um objeto pode ser gravado na API. A NetworkPolicy decide quais pacotes de rede chegam no Pod depois que ele já existe. O SOPS decide quem consegue ler um arquivo no Git. Nenhum dos três substitui o outro.

## Kyverno

O Kyverno é um admission webhook. O chart 3.9.2 sobe quatro controladores no namespace `kyverno`: admission, background, cleanup e reports. O admission registra um `ValidatingWebhookConfiguration`. Quando o API server recebe um Pod, ele pausa a gravação e pergunta ao Kyverno. `validationFailureAction: Enforce` faz o API server devolver 403. `Audit` só registraria.

As políticas são `ClusterPolicy` (grupo `kyverno.io/v1`) em [policies](../../policies). Cada regra tem um `match` restrito aos namespaces `referencia-dev` e `referencia-prod`. Um chart de terceiro, no namespace dele, não passa por essas regras. A cerca está no serviço que este repositório entrega, não no ingress-nginx nem no Prometheus.

| Política | O que o `pattern` exige |
|---|---|
| `exigir-limits` | `requests` e `limits` de `cpu` e `memory` em todo container. `?*` no Kyverno significa "qualquer valor não vazio" |
| `proibir-tag-latest` | imagem com tag, e a tag diferente de `latest` |
| `exigir-non-root` | `runAsNonRoot`, sem `allowPrivilegeEscalation`, `capabilities.drop` contendo `ALL` |

O controlador também gera, no `status.autogen`, a mesma regra para Deployment, StatefulSet, DaemonSet e Job. Sem isso, um Deployment sem resources passaria no admission (o objeto não é um Pod) e o Pod criado pelo ReplicaSet seria o único recusado, com uma mensagem pior de ler. O Argo CD ignora esse `status` para não marcar a política como OutOfSync.

Prova, com o cluster no ar:

```bash
kubectl apply -f policies/fixtures/pod-invalido.yaml
```

O manifesto pede `image: nginx:latest`, não declara resources e não tem securityContext, no namespace `referencia-dev`. A resposta do API server cita as três regras. O arquivo não está no `kustomization.yaml` das políticas. Se estivesse, o Argo CD tentaria aplicá-lo para sempre e a Application `policies` ficaria Degraded.

## NetworkPolicy

O objeto em [deploy/referencia/base/networkpolicy.yaml](../../deploy/referencia/base/networkpolicy.yaml) seleciona os Pods `app.kubernetes.io/name: referencia` e declara `policyTypes: [Ingress]`. A partir daí, tráfego de entrada na porta 8080 só entra se a origem estiver numa destas regras:

- qualquer Pod do mesmo namespace (`podSelector: {}`)
- Pods do namespace `ingress-nginx` (o label `kubernetes.io/metadata.name` é automático)
- Pods do namespace `monitoring` (o Prometheus)
- o CIDR `172.16.0.0/12`

A última regra é específica do kind. O kubelet faz readiness e liveness a partir da bridge do Docker, não a partir de um Pod. Sem o `ipBlock`, a probe falha, o Pod nunca fica Ready e o Deployment fica em 0 réplicas disponíveis mesmo com o processo saudável. Num cluster gerenciado esse CIDR seria o da rede dos nós, não o da bridge do Docker Desktop.

Egress não está restrito. O workload não abre conexão de saída. A policy não finge que restringe o que não restringe.

## SOPS e age

SOPS cifra valores dentro de um YAML e deixa as chaves legíveis. O arquivo [platform/secrets/grafana-admin.yaml](../../platform/secrets/grafana-admin.yaml) tem `stringData.admin-user` e `stringData.admin-password` no formato `ENC[AES256_GCM,...]`. A regra de criação está em [.sops.yaml](../../.sops.yaml): qualquer arquivo cujo caminho termine em `grafana-admin.yaml` usa a chave age pública.

age é o algoritmo. A chave privada de desenvolvimento está em `keys/dev.agekey`. `make grafana-password` exporta `SOPS_AGE_KEY_FILE` para esse arquivo e roda `sops -d`. O Terraform faz a mesma decifragem no apply e grava o Secret `grafana-admin` no namespace `monitoring` antes do Helm do Grafana subir.

A senha decifrada é `prumo-dev-admin`, usuário `admin`. A chave privada está no Git de propósito, para o `make up` funcionar num clone novo. Isso não é um cofre. O [ADR 0004](../adr/0004-sops-com-chave-de-desenvolvimento.md) registra o limite: a mesma receita com uma chave que não está no repositório é o que um time usa fora deste sandbox.
