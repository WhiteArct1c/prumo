# 2. Kubernetes

O Kubernetes guarda o estado que você declarou e trabalha até o cluster chegar nele. Você não liga um processo. Você entrega um Deployment, e o controlador cria e recria Pods até o número pedido existir.

Os manifestos crus estão em [deploy/referencia/base](../../deploy/referencia/base):

| Arquivo | Função |
|---|---|
| `namespace.yaml` | A cerca em volta deste serviço |
| `deployment.yaml` | Quantos Pods, qual imagem, probes e limites |
| `service.yaml` | Um endereço estável para os Pods, que trocam de IP |
| `ingress.yaml` | O nome `referencia.localhost` chega no Service |
| `networkpolicy.yaml` | Quem pode falar com o Pod na porta 8080 |
| `certificate.yaml` | O cert-manager emite o TLS desse host |

O Deployment pede a imagem `prumo-referencia:local` com `imagePullPolicy: IfNotPresent`. O cluster usa a imagem que o `make up` carregou, e só tenta um registry se ela não estiver lá.

Probes em `/healthz` dizem ao kubelet se o processo deve receber tráfego (`readiness`) e se deve ser reiniciado (`liveness`). `resources.requests` reservam cpu e memória. `resources.limits` marcam o teto. Sem isso, um vizinho no mesmo nó pode ser espremido.

Para ver o efeito com a mão, com o cluster no ar e a imagem carregada:

```bash
kubectl apply -k deploy/referencia/base
kubectl -n referencia rollout status deployment/referencia
kubectl -n referencia port-forward svc/referencia 8080:80
```

O capítulo seguinte para de editar esses arquivos à mão para cada ambiente. O Kustomize gera `dev` e `prod` a partir desta base.
