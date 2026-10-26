# 4. Argo CD

`kubectl apply` a partir de um laptop não deixa rastro, e o cluster pode divergir do Git no minuto seguinte. O Argo CD fica dentro do cluster, lê o Git e aplica de novo até o cluster bater com o que está commitado. Isso se chama reconciliação.

O Prumo usa o desenho app-of-apps. O Terraform instala o Argo CD e uma única Application, a `root`, em [platform/root/templates/application.yaml](../../platform/root/templates/application.yaml). Essa Application aponta para [platform/apps](../../platform/apps). Cada arquivo ali é outra Application: ingress, cert-manager, Kyverno, Prometheus, políticas, observabilidade e os dois overlays.

As peças de terceiro vêm de repositórios Helm públicos. O que é nosso vem do Git local `git://git.git.svc.cluster.local/prumo`. Esse endereço é um `git daemon` no cluster, servindo a pasta do repositório montada no nó. Por isso o Argo CD só enxerga commit. Arquivo salvo e não commitado não existe para ele.

A sincronização é automática, com prune e selfHeal. Prune apaga do cluster o que saiu do Git. SelfHeal desfaz uma mudança feita com `kubectl` na mão, se ela divergir do Git.

A ordem entre as Applications é a annotation `argocd.argoproj.io/sync-wave`. O ingress sobe antes do cert-manager e do Kyverno. O workload sobe depois das políticas. A wave espera a Application anterior ficar saudável.

Abra `http://argocd.localhost:8080` quando o `make up` terminar. O usuário é `admin`. A senha sai de `make argocd-password`.
