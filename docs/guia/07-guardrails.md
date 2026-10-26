# 7. Guardrails

A plataforma recusa o que não deve entrar nos namespaces do workload. Três políticas Kyverno, em [policies](../../policies), valem só para `referencia-dev` e `referencia-prod`:

- `exigir-limits` exige requests e limits de cpu e memória
- `proibir-tag-latest` exige uma tag e recusa `latest`
- `exigir-non-root` exige usuário sem root, sem escalar privilégio e sem capabilities

Charts de terceiro ficam de fora. Eles têm dono e ciclo próprios. A cerca está no caminho do serviço que este repositório entrega.

O Pod em [policies/fixtures/pod-invalido.yaml](../../policies/fixtures/pod-invalido.yaml) usa a tag `latest` e não declara recursos. Com as políticas aplicadas:

```bash
kubectl apply -f policies/fixtures/pod-invalido.yaml
```

O API server recusa. A mensagem vem do Kyverno.

A NetworkPolicy do workload só aceita conexão na porta 8080 vinda do próprio namespace, do `ingress-nginx`, do `monitoring` e da rede dos nós. A última entrada existe porque, no kind, o probe do kubelet sai da bridge do Docker (`172.16.0.0/12`). Num cluster gerenciado, esse bloco seria o CIDR dos nodes.

O Secret do Grafana está em [platform/secrets/grafana-admin.yaml](../../platform/secrets/grafana-admin.yaml), cifrado com SOPS e age. `make grafana-password` mostra o conteúdo. A chave que abre o arquivo está em `keys/dev.agekey` para o `make up` funcionar numa máquina nova. Leia o ADR 0004 antes de copiar esse padrão para qualquer outro lugar.
