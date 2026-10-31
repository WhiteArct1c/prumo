# 3. Kustomize

## What it is

Kustomize is a YAML generator. It is not a template with `if`. You declare a base and a list of patches. `kustomize build` prints the objects with namespace, replicas, image, and patches already applied. `kubectl apply -k` and Argo CD consume that output. The cluster never sees `kustomization.yaml`. It sees Deployment, Service, Ingress.

Helm, used for third-party pieces, is another generator: a chart with `values.yaml` and templates. Here Helm installs ingress-nginx, cert-manager, Kyverno, kube-prometheus-stack, and Argo CD. Kustomize describes what is ours, because the gap between `dev` and `prod` is small and does not need a template language. The same tool lists which Argo CD Applications exist: [platform/apps/lite](../../platform/apps/lite) and [platform/apps/full](../../platform/apps/full) both include [platform/apps/common](../../platform/apps/common). `full` also includes [platform/lgtm](../../platform/lgtm).

## Base and overlays

The base in [deploy/prumo/base/kustomization.yaml](../../deploy/prumo/base/kustomization.yaml) lists the six objects and the `images` block, where the image tag is swapped by the CI `release` job.

The overlay does not copy the Deployment. It points at the base:

- [overlays/dev](../../deploy/prumo/overlays/dev): namespace `prumo-dev`, `replicas: 1`, `ENVIRONMENT=dev` patch, host `dev.prumo.test`
- [overlays/prod](../../deploy/prumo/overlays/prod): namespace `prumo-prod`, `replicas: 2`, `ENVIRONMENT=prod` patch, host `prod.prumo.test`

The `namespace` field in `kustomization.yaml` rewrites `metadata.namespace` on every object, including the Namespace. The patches are Strategic Merge: a Deployment with the same `metadata.name` and only the `env` field replaces that field and keeps the rest of the base (probes, resources, securityContext, image).

The image is the same in both overlays. What changes is configuration: replicas, namespace, variable, and hostname. That is the line between "promote the artifact" and "rewrite the service".

## See the YAML the cluster gets

```bash
kustomize build deploy/prumo/overlays/dev
kustomize build deploy/prumo/overlays/prod
```

Check three lines in the prod output: `replicas: 2`, `value: prod`, and `host: prod.prumo.test`. If the patch did not apply, the object name in the patch does not match the base. Kustomize ignores a file silently only when it is not listed. If it is listed and the name is wrong, the build fails.

CI runs that build and pipes the output through kubeconform, against the Kubernetes schemas pinned in the workflow. An object with a made-up field breaks the pipeline before it exists in the cluster.
