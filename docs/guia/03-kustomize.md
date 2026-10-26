# 3. Kustomize

A base descreve o serviço uma vez. O overlay diz o que muda no ambiente. `dev` e `prod` não são duas cópias do Deployment. São a mesma base com três diferenças: namespace, número de réplicas e host.

- [overlays/dev](../../deploy/referencia/overlays/dev) usa o namespace `referencia-dev`, 1 réplica e `referencia.dev.localhost`
- [overlays/prod](../../deploy/referencia/overlays/prod) usa `referencia-prod`, 2 réplicas e `referencia.prod.localhost`

O campo `namespace` do `kustomization.yaml` reescreve o namespace de todos os recursos, inclusive o objeto Namespace. O patch do Deployment troca só a variável `ENVIRONMENT`. O patch do Ingress troca o host.

Veja o YAML final, sem aplicar nada:

```bash
kustomize build deploy/referencia/overlays/dev
kustomize build deploy/referencia/overlays/prod
```

A imagem publicada pela Actions é trocada na base, no bloco `images` de [kustomization.yaml](../../deploy/referencia/base/kustomization.yaml). Os dois ambientes passam a apontar para a mesma tag. A configuração muda. O artefato, não.
