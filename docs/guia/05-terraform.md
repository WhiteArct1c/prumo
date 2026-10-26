# 5. Terraform

O Terraform cria o chão e para. Neste repositório ele faz quatro coisas:

1. Cria o cluster kind, com as portas 8080 e 8443 do seu computador ligadas às portas 80 e 443 do nó, e com a pasta do repositório montada em `/git/prumo`.
2. Carrega a imagem `prumo-referencia` dentro desse cluster.
3. Sobe o `git daemon` e o Argo CD.
4. Decifra a senha do Grafana com SOPS e grava o Secret `grafana-admin`. Aí aplica a Application `root`.

O Deployment do workload não está no Terraform. Cada mudança de réplica, host ou tag seria um apply com estado, lock e blast radius grande. Quem muda isso é um commit, e quem aplica é o Argo CD.

O estado fica em `terraform/terraform.tfstate`, fora do Git. O kubeconfig fica em `.cache/kubeconfig`. Os dois são locais, da sua máquina.

`make up` é a ordem: construir a imagem, `terraform init`, `terraform apply`. `make down` destrói o cluster.
