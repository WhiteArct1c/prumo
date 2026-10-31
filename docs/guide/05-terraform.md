# 5. Terraform

## What it is

Terraform reads `.tf` files, builds a resource graph, and calls each provider's API until the world matches that graph. State (`terraform/terraform.tfstate`) stores the id of what was already created. The next `apply` diffs the code against that state. Destroy is `terraform destroy`, which walks the graph backwards.

It is not the place for the workload Deployment. Replicas, host, and tag change all the time. Each of those as a Terraform resource would be an apply, a lock, and a state that now contains the service. A commit changes the service. Argo CD applies it. Terraform creates the ground Argo CD needs to read Git.

## What it creates here

Provider `tehcyx/kind` 0.11.0, Helm 2.17.0, Kubernetes 2.38.0, SOPS 1.4.1. Terraform 1.17.0.

1. **kind cluster** in [terraform/cluster.tf](../../terraform/cluster.tf). One `kindest/node:v1.32.2` node. kind 0.33 uses Kubernetes 1.37 by default, and that version does not finish `kubeadm init` on Docker Desktop when the daemon is still on cgroup v1. 1.32 starts. The node publishes `host 8080 → container 80` and `host 8443 → container 443`, only on `127.0.0.1`. Without `listen_address`, Docker would publish on every interface and Grafana would be open to the local network. The node mounts the repository `.git` at `/git/prumo/.git`, read-only. The whole folder would bring `terraform.tfstate` and the kubeconfig along.
2. **Image load.** The provider has no `kind_load` resource. Two `terraform_data` resources call `kind load docker-image` for the workload image and for `prumo-git:local`. The workload image name is whatever the `dev` overlay asks for: `prumo:local` until the first CI release, `ghcr.io/<owner>/prumo:<tag>` after that. Without the load, the kubelet sits in `ImagePullBackOff`, because the `local` tag exists in no registry.
3. **Git daemon** in [terraform/git.tf](../../terraform/git.tf). Namespace `git`, Deployment with image `prumo-git:local` and `imagePullPolicy: IfNotPresent`. The command is `git daemon --base-path=/git --export-all` on port 9418. Service `git.git.svc.cluster.local` is the host the Applications use.
4. **Argo CD and the `root` Application.** Helm release in the `argocd` namespace, values from [platform/argocd-values.yaml](../../platform/argocd-values.yaml). Then the local `platform/root` chart creates the Application that points at `platform/apps`.
5. **Grafana Secret.** [terraform/secrets.tf](../../terraform/secrets.tf) reads `platform/secrets/grafana-admin.yaml` with the SOPS provider, creates the `monitoring` namespace and the `grafana-admin` Secret before kube-prometheus-stack. The Grafana chart uses `existingSecret` and does not generate its own password.

The kubeconfig lands in `.cache/kubeconfig`. State and kubeconfig stay out of Git.

## make up

`make up` is the order, not one more resource:

1. Refuses to continue if there is no commit (`check-commit`). The daemon would serve a repository with no HEAD and Argo CD would not clone.
2. `docker build` of both images.
3. `terraform init` and `terraform apply` with `repo_host_path` (this clone's folder), `app_image` (the tag read from the dev overlay), and the kubeconfig path.

The apply finishes when Argo CD and the `root` Application exist. The other Applications keep syncing after that. `make status` lists `SYNC STATUS` and `HEALTH STATUS`. The first kube-prometheus-stack sync is the longest.

`make down` runs `terraform destroy` and then `kind delete cluster --name prumo`. Both have `-` in the Makefile: an error on destroy does not stop the attempt to delete the node.

`TF_IN_AUTOMATION=1` turns off Terraform's colored prompt. The apply uses `-auto-approve` because this state is local and disposable.
