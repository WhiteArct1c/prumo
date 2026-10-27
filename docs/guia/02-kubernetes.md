# 2. Kubernetes

## O que é

O Kubernetes é um controlador de estado. Você grava objetos na API (`https://kubernetes.default.svc` dentro do cluster, a porta 6443 do nó a partir da sua máquina). Cada objeto tem um `spec` (o que você pediu) e um `status` (o que o controlador conseguiu). O kubelet, no nó, cria os containers. Se um Pod morre, o Deployment cria outro até `spec.replicas` bater com o número de Pods Ready.

Este cluster é um kind: um nó Kubernetes inteiro dentro de um container Docker, imagem `kindest/node:v1.32.2`. A API, o etcd, o scheduler e o kubelet rodam nesse único nó. Não é um cluster de produção. É o mesmo modelo de objetos (Deployment, Service, Ingress) que um cluster gerenciado usa.

O kubeconfig que o `kubectl` lê está em `.cache/kubeconfig`. Ele aponta para o API server publicado pelo container do nó.

## Os objetos deste serviço

A base está em [deploy/referencia/base](../../deploy/referencia/base). Cada arquivo é um objeto da API.

**Namespace** (`referencia` na base; `referencia-dev` e `referencia-prod` depois do Kustomize). É a fronteira de nome, de RBAC e de NetworkPolicy. Dois Deployments com o mesmo nome podem coexistir se estiverem em namespaces diferentes.

**Deployment.** Pede 1 réplica na base. O template do Pod carrega a imagem `prumo-referencia:local` com `imagePullPolicy: IfNotPresent`. O containerd usa a imagem que o `kind load` colocou no nó e só consulta um registry se ela não existir. O container escuta 8080. Duas probes HTTP em `/healthz`:

- readiness, a cada 10s: enquanto falhar, o Service não manda tráfego para esse Pod
- liveness, a cada 20s: se falhar, o kubelet mata o container e o Deployment sobe outro

`resources.requests` (20m de cpu, 32Mi de memória) entram na conta do scheduler. `resources.limits` (200m, 64Mi) são o teto que o runtime aplica. Sem limits, o Kyverno recusa o Pod nos namespaces do workload.

O `securityContext` fixa `runAsUser: 10001`, `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false` e `capabilities.drop: [ALL]`. Isso é o mesmo contrato que a política `exigir-non-root` cobra.

**Service.** Tipo ClusterIP, porta 80, `targetPort` no nome `http` (a 8080 do container). O ClusterIP não muda quando o Pod é recriado. O selector `app.kubernetes.io/name: referencia` escolhe os Pods. O Ingress e o Prometheus falam com o Service, não com o IP do Pod.

**Ingress.** Classe `nginx`. O host da base é `referencia.localhost`. O overlay troca para `referencia.dev.localhost` ou `referencia.prod.localhost`. O caminho `/` vai para o Service na porta de nome `http`. A annotation `nginx.ingress.kubernetes.io/ssl-redirect: "false"` é obrigatória aqui: o nginx, por padrão, responde 308 e manda o cliente para a porta 443 do host. Essa porta não está publicada. O HTTPS do cluster sai na 8443 da sua máquina. Sem a annotation, `curl` na 8080 não chega no workload.

**NetworkPolicy.** Ver o [guia 7](07-guardrails.md). Sem ela, qualquer Pod do cluster alcança a 8080.

**Certificate.** Pede um certificado ao cert-manager para o host do Ingress. O Secret resultante é o `referencia-tls` citado no bloco `tls` do Ingress.

## Portas, do seu navegador até o processo

```
navegador  referencia.dev.localhost:8080
    → porta 8080 do Windows
    → porta 80 do container do nó kind          (extra_port_mappings do Terraform)
    → ingress-nginx escutando hostPort 80       (Pod com toleration de control-plane)
    → Service referencia:80
    → Pod :8080
    → server.py
```

A porta 80 do Windows está ocupada pelo HTTP.sys (`svchost`). Por isso o host usa 8080 e 8443, não 80 e 443.

`*.localhost` resolve para `127.0.0.1` sem entrada no arquivo hosts. O navegador e o `curl` já encontram o ingress.

## Aplicar na mão

Com o cluster no ar e a imagem carregada, a base sobe sem o Argo CD:

```bash
kubectl apply -k deploy/referencia/base
kubectl -n referencia rollout status deployment/referencia
kubectl -n referencia port-forward svc/referencia 8080:80
```

Esse `kubectl apply` é o que o capítulo 4 deixa de ser o caminho normal. Ele não fica registrado no Git, e o selfHeal do Argo CD desfaz o que divergir do commit.
