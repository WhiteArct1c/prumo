# 3. Kustomize

## O que é

Kustomize é um gerador de YAML. Ele não é um template com `if`. Você declara uma base e uma lista de patches. `kustomize build` imprime os objetos já com namespace, réplicas, imagem e patches aplicados. O `kubectl apply -k` e o Argo CD consomem essa saída. O cluster nunca vê o `kustomization.yaml`. Ele vê Deployment, Service, Ingress.

Helm, usado nas peças de terceiro, é outro gerador: chart com `values.yaml` e templates. Aqui o Helm instala ingress-nginx, cert-manager, Kyverno, kube-prometheus-stack e o Argo CD. O Kustomize descreve o que é nosso, porque a diferença entre `dev` e `prod` é pequena e não precisa de linguagem de template.

## Base e overlays

A base em [deploy/prumo/base/kustomization.yaml](../../deploy/prumo/base/kustomization.yaml) lista os seis objetos e o bloco `images`, onde a tag da imagem é trocada pelo workflow de release.

O overlay não copia o Deployment. Ele aponta para a base:

- [overlays/dev](../../deploy/prumo/overlays/dev): namespace `prumo-dev`, `replicas: 1`, patch de `ENVIRONMENT=dev`, host `dev.prumo.test`
- [overlays/prod](../../deploy/prumo/overlays/prod): namespace `prumo-prod`, `replicas: 2`, patch de `ENVIRONMENT=prod`, host `prod.prumo.test`

O campo `namespace` do `kustomization.yaml` reescreve `metadata.namespace` de todo objeto, inclusive o Namespace. Os patches são Strategic Merge: um Deployment com o mesmo `metadata.name` e só o campo `env` substitui esse campo e mantém o resto da base (probes, resources, securityContext, imagem).

A imagem é a mesma nos dois overlays. O que muda é configuração: réplicas, namespace, variável e hostname. É o critério que separa "promover o artefato" de "reescrever o serviço".

## Ver o YAML que o cluster recebe

```bash
kustomize build deploy/prumo/overlays/dev
kustomize build deploy/prumo/overlays/prod
```

Confira três linhas na saída de prod: `replicas: 2`, `value: prod` e `host: prod.prumo.test`. Se o patch não entrou, o nome do objeto no patch não bate com o da base e o Kustomize ignora o arquivo em silêncio só quando ele não está listado. Se está listado e o nome erra, o build falha.

O CI roda esse build e passa a saída no kubeconform, contra os schemas do Kubernetes 1.32. Objeto com campo inventado quebra o pipeline antes de existir no cluster.
