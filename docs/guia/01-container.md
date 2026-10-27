# 1. Container

## O que é

Uma imagem Docker é um sistema de arquivos em camadas mais um comando de arranque. Ela não é um processo. O container é o processo criado a partir dessa imagem, com o próprio namespace de rede, de PID e de filesystem. A imagem pode ser copiada para outra máquina. O container morre com o processo.

O formato que o Docker grava é o OCI image. O Kubernetes não fala com o Dockerfile. Ele pede ao container runtime (no kind, o `containerd` do nó) para criar um container a partir de uma imagem que já está no nó ou que ele consegue puxar de um registry.

## O que este workload faz

O programa está em [apps/referencia/server.py](../../apps/referencia/server.py). É a biblioteca padrão do Python, sem framework. O `ThreadingHTTPServer` escuta `0.0.0.0` na porta `PORT` (8080).

| Caminho | Resposta | Quem usa |
|---|---|---|
| `/` | texto com o valor de `ENVIRONMENT` | você, no navegador |
| `/healthz` | `ok` e HTTP 200 | readiness e liveness do Kubernetes, e o `HEALTHCHECK` do Docker |
| `/metrics` | texto Prometheus: `prumo_up`, `prumo_info` e o contador `prumo_requests_total` | o Prometheus, via ServiceMonitor |

`ENVIRONMENT` não muda o código. O mesmo binário (aqui, o mesmo `server.py`) roda em `dev` e em `prod`. O overlay só injeta a variável.

## Como a imagem é montada

O [Dockerfile](../../apps/referencia/Dockerfile) faz isto, nesta ordem:

1. Parte de `python:3.12-slim`. Essa base já traz o interpretador. Não instalamos pacote nenhum.
2. `PYTHONDONTWRITEBYTECODE=1` impede o Python de criar `__pycache__`. No cluster o filesystem raiz do container é somente leitura, e esse arquivo faria o processo cair na subida.
3. `useradd --uid 10001` cria um usuário sem login. O `USER 10001` faz o processo nascer com esse uid. O número precisa ser o mesmo que o Deployment declara em `runAsUser`.
4. `EXPOSE 8080` é documentação para quem lê a imagem. Quem publica a porta é o `docker run -p` ou o `containerPort` do Pod.
5. O `HEALTHCHECK` chama `/healthz` de dentro do container. O Kubernetes não usa esse healthcheck. Ele usa as probes do Deployment. Os dois existem porque a imagem também roda fora do cluster.

Construir e rodar fora do Kubernetes:

```bash
docker build -t prumo-referencia:local apps/referencia
docker run --rm --read-only -p 8080:8080 -e ENVIRONMENT=local prumo-referencia:local
```

`--read-only` reproduz a restrição que o Pod aplica. Se o processo precisar escrever na raiz, ele quebra aqui, antes de chegar no cluster.

```bash
curl http://127.0.0.1:8080/healthz
curl http://127.0.0.1:8080/metrics
```

Pare com Ctrl+C. A imagem `prumo-referencia:local` continua no Docker. O `make up` carrega essa tag para dentro do nó kind com `kind load docker-image`. Sem registry, a tag `local` só existe na sua máquina e nesse nó.
