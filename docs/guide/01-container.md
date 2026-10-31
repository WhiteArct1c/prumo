# 1. Container

## What it is

A Docker image is a layered filesystem plus a start command. It is not a process. The container is the process created from that image, with its own network, PID, and filesystem namespaces. The image can be copied to another machine. The container dies with the process.

The format Docker writes is the OCI image. Kubernetes does not talk to the Dockerfile. It asks the container runtime (on kind, `containerd` on the node) to create a container from an image that is already on the node or that it can pull from a registry.

## What this workload does

The program lives in [apps/prumo/server.py](../../apps/prumo/server.py). It is the Python standard library, no framework. `ThreadingHTTPServer` listens on `0.0.0.0` on `PORT` (8080).

| Path | Response | Who uses it |
|---|---|---|
| `/` | text with the `ENVIRONMENT` value | you, in the browser |
| `/healthz` | `ok` and HTTP 200 | Kubernetes readiness and liveness, and the Docker `HEALTHCHECK` |
| `/metrics` | Prometheus text: `prumo_up`, `prumo_info`, and the `prumo_requests_total` counter | Prometheus, through a ServiceMonitor |

`ENVIRONMENT` does not change the code. The same binary (here, the same `server.py`) runs in `dev` and in `prod`. The overlay only injects the variable.

## How the image is built

The [Dockerfile](../../apps/prumo/Dockerfile) does this, in this order:

1. Starts from the slim Python image named in the Dockerfile. That base already has the interpreter. We install no packages. The tag is a README shield.
2. `PYTHONDONTWRITEBYTECODE=1` stops Python from creating `__pycache__`. In the cluster the container root filesystem is read-only, and that file would crash the process on start.
3. `useradd --uid 10001` creates a user with no login. `USER 10001` starts the process with that uid. The number has to match what the Deployment declares in `runAsUser`.
4. `EXPOSE 8080` is documentation for whoever reads the image. What publishes the port is `docker run -p` or the Pod `containerPort`.
5. The `HEALTHCHECK` calls `/healthz` from inside the container. Kubernetes does not use that healthcheck. It uses the Deployment probes. Both exist because the image also runs outside the cluster.

Build and run outside Kubernetes:

```bash
docker build -t prumo:local apps/prumo
docker run --rm --read-only -p 8080:8080 -e ENVIRONMENT=local prumo:local
```

`--read-only` matches the restriction the Pod applies. If the process needs to write at the root, it breaks here, before it reaches the cluster.

```bash
curl http://127.0.0.1:8080/healthz
curl http://127.0.0.1:8080/metrics
```

Stop with Ctrl+C. The `prumo:local` image stays in Docker. That tag is only for this manual run.

`make up` does not load `prumo:local`. It builds the name the dev overlay asks for and `kind load`s that name into the node. The base [`images`](../../deploy/prumo/base/kustomization.yaml) block is what the overlay asks for. After the first release the block is `ghcr.io/<owner>/prumo:<tag>`, and the tag is the content hash of `apps/prumo`. A clone still does not pull from GHCR: the build uses this tree. The other image `make up` loads is `prumo-git:local`, for the git daemon. [Guide 5](05-terraform.md) and [guide 6](06-ci.md) are the source for that path.
