# 5. Terraform

## O que é

O Terraform lê arquivos `.tf`, calcula um grafo de recursos e chama a API de cada provider até o mundo bater com esse grafo. O estado (`terraform/terraform.tfstate`) guarda o id do que já foi criado. O próximo `apply` faz a diferença entre o código e esse estado. Destruir é `terraform destroy`, que percorre o grafo ao contrário.

Ele não é o lugar do Deployment do workload. Réplica, host e tag mudam o tempo todo. Cada uma dessas mudanças como recurso Terraform seria apply, lock e um estado que agora contém o serviço. Quem muda o serviço é um commit. Quem aplica é o Argo CD. O Terraform cria o chão em que o Argo CD consegue ler Git.

## O que ele cria aqui

Provider `tehcyx/kind` 0.11.0, Helm 2.17.0, Kubernetes 2.38.0, SOPS 1.4.1. Terraform 1.17.0.

1. **Cluster kind** em [terraform/cluster.tf](../../terraform/cluster.tf). Um nó `kindest/node:v1.32.2`. O kind 0.33 usa Kubernetes 1.37 por padrão, e essa versão não termina o `kubeadm init` no Docker Desktop quando o daemon ainda está em cgroup v1. A 1.32 inicia. O nó publica `host 8080 → container 80` e `host 8443 → container 443`, e monta a pasta do repositório em `/git/prumo`, somente leitura.
2. **Carga das imagens.** O provider não tem recurso `kind_load`. Dois `terraform_data` chamam `kind load docker-image` para `prumo-referencia:local` e `prumo-git:local`. Sem isso o kubelet fica em `ImagePullBackOff`, porque a tag `local` não existe em registry nenhum.
3. **Git daemon** em [terraform/git.tf](../../terraform/git.tf). Namespace `git`, Deployment com a imagem `prumo-git:local` e `imagePullPolicy: IfNotPresent`. O comando é `git daemon --base-path=/git --export-all` na porta 9418. O Service `git.git.svc.cluster.local` é o host que as Applications usam.
4. **Argo CD e a Application `root`.** Helm release no namespace `argocd`, values de [platform/argocd-values.yaml](../../platform/argocd-values.yaml). Em seguida o chart local `platform/root` cria a Application que aponta para `platform/apps`.
5. **Secret do Grafana.** [terraform/secrets.tf](../../terraform/secrets.tf) lê `platform/secrets/grafana-admin.yaml` com o provider SOPS, cria o namespace `monitoring` e o Secret `grafana-admin` antes do kube-prometheus-stack. O chart do Grafana usa `existingSecret` e não gera senha própria.

O kubeconfig sai em `.cache/kubeconfig`. Estado e kubeconfig ficam de fora do Git.

## make up

`make up` é a ordem, não um recurso a mais:

1. Recusa seguir se não houver commit (`check-commit`). O daemon serviria um repositório sem HEAD e o Argo CD não clonaria.
2. `docker build` das duas imagens.
3. `terraform init` e `terraform apply` com `repo_host_path` (a pasta deste clone), `app_image` (a tag lida do overlay dev) e o caminho do kubeconfig.

O apply termina quando o Argo CD e a Application `root` existem. As outras Applications continuam sincronizando depois. `make status` lista `SYNC STATUS` e `HEALTH STATUS`. A primeira sincronização do kube-prometheus-stack é a mais longa.

`make down` roda `terraform destroy` e, em seguida, `kind delete cluster --name prumo`. Os dois têm `-` no Makefile: um erro no destroy não impede a tentativa de apagar o nó.

`TF_IN_AUTOMATION=1` desliga a pergunta colorida do Terraform. O apply usa `-auto-approve` porque este estado é local e descartável.
