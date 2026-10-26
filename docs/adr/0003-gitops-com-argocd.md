# ADR 0003: GitOps com Argo CD

## Contexto

O cluster precisa ter uma fonte da verdade que outra pessoa possa ler. Um pipeline que executa `kubectl apply` guarda a verdade no histórico do runner, não no repositório.

## Decisão

O Argo CD é o único componente que aplica o que está em [platform/apps](../../platform/apps) e em [deploy/referencia](../../deploy/referencia). A sincronização é automática. O CI constrói a imagem, escaneia e, no workflow de release, atualiza a tag no Git. Ele não aplica manifesto de produção.

No laptop, o Git que o Argo CD lê é um `git daemon` dentro do cluster, porque o repositório ainda não precisa existir no GitHub para o `make up` funcionar. O remoto passa a ser o GitHub quando o repositório for publicado. A Application troca o `repoURL`. O resto do desenho fica.

## Consequências

Nada entra no cluster sem commit. A interface do Argo CD mostra o que divergiu. O custo é operar mais um controlador, e aceitar que arquivo não commitado é invisível para o cluster.
