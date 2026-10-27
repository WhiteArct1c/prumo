# 9. Colocar outra aplicação neste cluster

O cluster que o `make up` sobe não está amarrado ao `server.py`. Ele já tem ingress, certificado, política de admissão, métricas e o Argo CD lendo este Git. Outra API entra como mais um workload ao lado de `prumo`, no mesmo kind.

O que a plataforma exige do processo, porque as políticas e a rede já estão assim:

- escutar HTTP numa porta fixa, com `/healthz` respondendo 200 quando o processo pode receber tráfego
- imagem com usuário numérico, não root
- no Pod: `requests` e `limits` de cpu e memória, sem tag `latest`, `runAsNonRoot`, sem escalar privilégio, `capabilities.drop: [ALL]`
- commit no Git. O Argo CD não aplica arquivo só salvo

As ClusterPolicies atuais só olham `prumo-dev` e `prumo-prod`. Um namespace novo não é recusado por elas até você acrescentar o nome no `match` de cada política. Faça isso se quiser a mesma cerca. Não faça isso se a aplicação for um experimento que ainda não cumpre as regras.

## Passos

1. **Imagem.** Um diretório em `apps/<nome>` com o Dockerfile. Construa uma tag local, por exemplo `prumo-<nome>:local`. Usuário numérico, porta declarada, processo capaz de subir com filesystem somente leitura se o Pod for usar `readOnlyRootFilesystem`.

2. **Manifestos.** Copie a forma de [deploy/prumo](../../deploy/prumo): uma base (Namespace, Deployment, Service, Ingress, NetworkPolicy, Certificate) e overlays `dev` e `prod` se você quiser os dois ambientes. Troque o nome, o `containerPort`, o host (`<nome>.prumo.test`) e o selector. O Ingress precisa de `ingressClassName: nginx` e de `nginx.ingress.kubernetes.io/ssl-redirect: "false"`. O host novo entra no arquivo `hosts`, apontando para `127.0.0.1`. A porta publicada na sua máquina continua sendo a 8080: vários hosts diferentes entram pelo mesmo ingress.

3. **Imagem dentro do nó.** Tag `local` não existe num registry. Rode `kind load docker-image prumo-<nome>:local --name prumo` e use `imagePullPolicy: IfNotPresent`. O `make up` só carrega `prumo:local` e `prumo-git:local`. Uma imagem nova precisa deste `kind load` depois de cada `make up`, ou de um `terraform_data` igual ao de [terraform/cluster.tf](../../terraform/cluster.tf).

4. **Application.** Um arquivo novo em `platform/apps/`, no modelo de [prumo-dev.yaml](../../platform/apps/prumo-dev.yaml): `repoURL: git://git.git.svc.cluster.local/prumo`, `path` no overlay, `targetRevision: HEAD`, `syncPolicy.automated` com `prune` e `selfHeal`, wave `"3"` para subir depois do ingress e das políticas. A `root` já aponta para o diretório inteiro. O arquivo novo entra na próxima reconciliação. Não é preciso alterar o Terraform.

5. **Commit.** `git add` e `git commit`. Em até uns 30 segundos a Application aparece em `kubectl get applications -n argocd`. `OutOfSync` com erro de manifest é o YAML. `ImagePullBackOff` é a imagem que não foi carregada no nó.

6. **Métricas, se a API expuser `/metrics`.** Um ServiceMonitor em `platform/observability`, selector no label do Service novo. Sem esse objeto o Prometheus não raspa o endpoint, mesmo que ele responda.

## O que não muda

Terraform continua só no cluster, no git daemon, no Argo CD e no Secret do Grafana. Não crie o Deployment novo em `terraform/`. O CI em `.github/workflows/ci.yml` só constrói `apps/prumo` e só aplica o overlay dev desse workload. Uma API nova precisa de um job próprio, ou de o job atual deixar de ter o caminho fixo, no dia em que o repositório for para o GitHub.
