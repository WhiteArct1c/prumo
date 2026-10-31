# 9. Put another application on this cluster

The cluster `make up` starts is not tied to `server.py`. It already has ingress, certificates, admission policy, metrics, and Argo CD reading this Git. Another API joins as one more workload next to `prumo`, on the same kind cluster.

What the platform asks of the process, because the policies and the network are already set this way:

- listen on HTTP on a fixed port, with `/healthz` answering 200 when the process can take traffic
- an image with a numeric user, not root
- on the Pod: cpu and memory `requests` and `limits`, no `latest` tag, `runAsNonRoot`, no privilege escalation, `capabilities.drop: [ALL]`
- a commit in Git. Argo CD does not apply a file that was only saved

The current ClusterPolicies only watch `prumo-dev` and `prumo-prod`. A new namespace is not rejected by them until you add the name to each policy `match`. Do that if you want the same fence. Skip it if the application is an experiment that does not meet the rules yet.

## Steps

1. **Image.** A directory under `apps/<name>` with the Dockerfile. Build a local tag, for example `prumo-<name>:local`. Numeric user, declared port, process able to start with a read-only filesystem if the Pod will use `readOnlyRootFilesystem`.

2. **Manifests.** Copy the shape of [deploy/prumo](../../deploy/prumo): a base (Namespace, Deployment, Service, Ingress, NetworkPolicy, Certificate) and `dev` / `prod` overlays if you want both environments. Change the name, the `containerPort`, the host (`<name>.prumo.test`), and the selector. The Ingress needs `ingressClassName: nginx` and `nginx.ingress.kubernetes.io/ssl-redirect: "false"`. The new host goes in the hosts file, pointing at `127.0.0.1`. The port published on your machine stays 8080: several different hosts enter through the same ingress.

3. **Image on the node.** A `local` tag exists in no registry. Run `kind load docker-image prumo-<name>:local --name prumo` and use `imagePullPolicy: IfNotPresent`. `make up` loads the sample workload under the name the dev overlay asks for, which after the first release is the GHCR name and tag in [deploy/prumo/base/kustomization.yaml](../../deploy/prumo/base/kustomization.yaml), and it loads `prumo-git:local`. It does not load `prumo-<name>:local`. A new image needs this `kind load` after every `make up`, or a `terraform_data` like the one in [terraform/cluster.tf](../../terraform/cluster.tf).

4. **Application.** A new file in [platform/apps/common](../../platform/apps/common), on the model of [prumo-dev.yaml](../../platform/apps/common/prumo-dev.yaml): `repoURL: git://git.git.svc.cluster.local/prumo`, `path` on the overlay, `targetRevision: HEAD`, `syncPolicy.automated` with `prune` and `selfHeal`, wave `"3"` so it comes up after ingress and the policies. Both `lite` and `full` include `common/`. Add the filename to [platform/apps/common/kustomization.yaml](../../platform/apps/common/kustomization.yaml). The AppProject `prumo` only allows the `prumo-dev` and `prumo-prod` namespaces. A new namespace also needs a destination on that AppProject, or the Application should land in one of those two namespaces. Terraform does not need to change.

5. **Commit.** `git add` and `git commit`. Within about 30 seconds the Application shows up in `kubectl get applications -n argocd`. `OutOfSync` with a manifest error is the YAML. `ImagePullBackOff` is the image that was not loaded into the node.

6. **Metrics, if the API exposes `/metrics`.** A ServiceMonitor in [platform/observability/base](../../platform/observability/base), selector on the new Service label. Without that object Prometheus does not scrape the endpoint, even if it answers. Logs and traces for the new service still need `PROFILE=full`.

## What does not change

Terraform still only covers the cluster, the git daemon, Argo CD, and the Grafana Secret. Do not create the new Deployment in `terraform/`. The CI in `.github/workflows/ci.yml` only builds `apps/prumo` and only applies that workload's dev overlay. A new API needs its own job, or the current job needs to stop hard-coding the path.
