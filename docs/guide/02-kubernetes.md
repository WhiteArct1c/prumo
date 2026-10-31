# 2. Kubernetes

## What it is

Kubernetes is a state controller. You write objects to the API (`https://kubernetes.default.svc` inside the cluster, port 6443 on the node from your machine). Each object has a `spec` (what you asked for) and a `status` (what the controller managed to do). The kubelet, on the node, creates the containers. If a Pod dies, the Deployment creates another until `spec.replicas` matches the number of Ready Pods.

This cluster is kind: a full Kubernetes node inside a Docker container, image `kindest/node:v1.32.2`. The API, etcd, the scheduler, and the kubelet run on that single node. It is not a production cluster. It is the same object model (Deployment, Service, Ingress) a managed cluster uses.

The kubeconfig `kubectl` reads is in `.cache/kubeconfig`. It points at the API server published by the node container.

## The objects for this service

The base lives in [deploy/prumo/base](../../deploy/prumo/base). Each file is one API object.

**Namespace** (`prumo` in the base; `prumo-dev` and `prumo-prod` after Kustomize). It is the name, RBAC, and NetworkPolicy boundary. Two Deployments with the same name can coexist if they sit in different namespaces.

**Deployment.** Asks for 1 replica in the base. The Pod template loads `prumo:local` with `imagePullPolicy: IfNotPresent`. containerd uses the image that `kind load` put on the node and only asks a registry if it is missing. The container listens on 8080. Two HTTP probes on `/healthz`:

- readiness, every 10s: while it fails, the Service does not send traffic to that Pod
- liveness, every 20s: if it fails, the kubelet kills the container and the Deployment starts another

`resources.requests` (20m cpu, 32Mi memory) go into the scheduler's math. `resources.limits` (200m, 64Mi) are the ceiling the runtime applies. Without limits, Kyverno rejects the Pod in the workload namespaces.

The `securityContext` sets `runAsUser: 10001`, `runAsNonRoot`, `readOnlyRootFilesystem`, `allowPrivilegeEscalation: false`, and `capabilities.drop: [ALL]`. That is the same contract the `require-non-root` policy asks for.

**Service.** ClusterIP, port 80, `targetPort` named `http` (container 8080). The ClusterIP does not change when the Pod is recreated. The selector `app.kubernetes.io/name: prumo` picks the Pods. Ingress and Prometheus talk to the Service, not to the Pod IP.

**Ingress.** Class `nginx`. The base host is `prumo.test`. The overlay swaps it to `dev.prumo.test` or `prod.prumo.test`. Path `/` goes to the Service on the port named `http`. The `nginx.ingress.kubernetes.io/ssl-redirect: "false"` annotation is required here: nginx, by default, answers 308 and sends the client to host port 443. That port is not published. Cluster HTTPS comes out on 8443 on your machine. Without the annotation, `curl` on 8080 never reaches the workload.

**NetworkPolicy.** See [guide 7](07-guardrails.md). Without it, any Pod in the cluster can reach 8080.

**Certificate.** Asks cert-manager for a certificate for the Ingress host. The resulting Secret is `prumo-tls`, cited in the Ingress `tls` block.

## Ports, from your browser to the process

```
browser  dev.prumo.test:8080
    → port 8080 on the host
    → port 80 on the kind node container     (Terraform extra_port_mappings)
    → ingress-nginx listening on hostPort 80 (Pod with a control-plane toleration)
    → Service prumo:80
    → Pod :8080
    → server.py
```

Port 80 on Windows is taken by HTTP.sys (`svchost`). That is why the host uses 8080 and 8443, not 80 and 443.

`dev.prumo.test`, `prod.prumo.test`, `argocd.prumo.test`, and `grafana.prumo.test` do not resolve on their own. All four need a line in `C:\Windows\System32\drivers\etc\hosts` (or `/etc/hosts`) pointing at `127.0.0.1`. The browser port stays 8080.

## Apply by hand

With the cluster up and the image loaded, the base comes up without Argo CD:

```bash
kubectl apply -k deploy/prumo/base
kubectl -n prumo rollout status deployment/prumo
kubectl -n prumo port-forward svc/prumo 8080:80
```

That `kubectl apply` is what chapter 4 stops treating as the normal path. It is not recorded in Git, and Argo CD's selfHeal undoes whatever drifts from the commit.
