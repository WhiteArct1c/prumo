# 1. Container

Uma imagem é o pacote: o programa, o interpretador e as bibliotecas, congelados. Um container é esse pacote rodando. Se o processo não sobe na imagem, o Kubernetes não tem o que reconciliar.

O workload de referência está em [apps/referencia/server.py](../../apps/referencia/server.py). Ele responde três caminhos:

- `/` diz em qual ambiente está
- `/healthz` responde `ok` quando o processo está vivo
- `/metrics` publica `prumo_up`, no formato que o Prometheus lê

O [Dockerfile](../../apps/referencia/Dockerfile) parte de `python:3.12-slim`, cria o usuário `10001` e troca para esse usuário antes de executar. O processo não roda como root. `PYTHONDONTWRITEBYTECODE` evita que o Python tente escrever arquivos numa raiz que, no cluster, será somente leitura.

Construa e rode na sua máquina:

```bash
docker build -t prumo-referencia:local apps/referencia
docker run --rm -p 8080:8080 -e ENVIRONMENT=local prumo-referencia:local
```

Em outro terminal:

```bash
curl http://127.0.0.1:8080/healthz
curl http://127.0.0.1:8080/metrics
```

Pare o container com Ctrl+C. A imagem continua no Docker. O container era só a execução.
