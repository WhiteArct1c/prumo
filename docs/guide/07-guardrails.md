# 7. Guardrails

Three different mechanisms, with roles that do not overlap.

Kyverno decides whether an object may be written to the API. NetworkPolicy decides which network packets reach the Pod after it already exists. SOPS decides who can read a file in Git. None of the three replaces another.

## Kyverno

Kyverno is an admission webhook. The chart starts four controllers in the `kyverno` namespace: admission, background, cleanup, and reports. Admission registers a `ValidatingWebhookConfiguration`. When the API server receives a Pod, it pauses the write and asks Kyverno. `validationFailureAction: Enforce` makes the API server return 403. `Audit` would only record.

The policies are `ClusterPolicy` objects (group `kyverno.io/v1`) in [policies](../../policies). Each rule has a `match` restricted to the `prumo-dev` and `prumo-prod` namespaces. A third-party chart, in its own namespace, does not go through these rules. The fence is on the service this repository ships, not on ingress-nginx or Prometheus.

| Policy | What the `pattern` requires |
|---|---|
| `require-limits` | `requests` and `limits` for `cpu` and `memory` on every container. `?*` in Kyverno means "any non-empty value" |
| `forbid-latest-tag` | an image with a tag, and a tag other than `latest` |
| `require-non-root` | `runAsNonRoot`, no `allowPrivilegeEscalation`, `capabilities.drop` containing `ALL` |

The controller also generates, in `status.autogen`, the same rule for Deployment, StatefulSet, DaemonSet, and Job. Without that, a Deployment with no resources would pass admission (the object is not a Pod) and the Pod created by the ReplicaSet would be the only one rejected, with a worse error. Argo CD ignores that `status` so it does not mark the policy OutOfSync.

Proof, with the cluster up:

```bash
kubectl apply -f policies/fixtures/invalid-pod.yaml
```

The manifest asks for `image: prumo:latest`, declares no resources, and has no securityContext, in the `prumo-dev` namespace. The API server response cites all three rules. The file is not in the policies `kustomization.yaml`. If it were, Argo CD would try to apply it forever and the `policies` Application would stay Degraded.

## NetworkPolicy

The object in [deploy/prumo/base/networkpolicy.yaml](../../deploy/prumo/base/networkpolicy.yaml) selects Pods `app.kubernetes.io/name: prumo` and declares `policyTypes: [Ingress]`. From then on, inbound traffic on port 8080 only enters if the source matches one of these rules:

- any Pod in the same namespace (`podSelector: {}`)
- Pods in the `ingress-nginx` namespace (the `kubernetes.io/metadata.name` label is automatic)
- Pods in the `monitoring` namespace (Prometheus)
- CIDR `172.16.0.0/12`

The last rule is kind-specific. The kubelet runs readiness and liveness from the Docker bridge, not from a Pod. Without the `ipBlock`, the probe fails, the Pod never becomes Ready, and the Deployment stays at 0 available replicas even with a healthy process. On a managed cluster that CIDR would be the node network, not the Docker Desktop bridge.

Egress is not restricted. The workload opens no outbound connection. The policy does not pretend to restrict what it does not restrict.

## SOPS and age

SOPS encrypts values inside a YAML file and leaves the keys readable. [platform/secrets/grafana-admin.yaml](../../platform/secrets/grafana-admin.yaml) has `stringData.admin-user` and `stringData.admin-password` in the `ENC[AES256_GCM,...]` form. The creation rule is in [.sops.yaml](../../.sops.yaml): any file whose path ends in `grafana-admin.yaml` uses the public age key.

age is the algorithm. The development private key is in `keys/dev.agekey`. `make grafana-password` exports `SOPS_AGE_KEY_FILE` to that file and runs `sops -d`. Terraform does the same decrypt on apply and writes the `grafana-admin` Secret in the `monitoring` namespace before the Grafana Helm release comes up.

The decrypted password is `prumo-dev-admin`, user `admin`. The private key is in Git on purpose, so `make up` works on a fresh clone. This is not a vault. [ADR 0004](../adr/0004-sops-with-a-dev-key.md) records the limit: the same recipe with a key that is not in the repository is what a team uses outside this sandbox.
