# Chave de desenvolvimento

`dev.agekey` abre os arquivos cifrados com SOPS neste repositório.

Ela está no Git de propósito: sem ela, `make up` não sobe numa máquina nova. A senha que ela protege é a senha de demonstração do Grafana. Não use esta chave fora deste laboratório. O [ADR 0004](../docs/adr/0004-sops-com-chave-de-desenvolvimento.md) explica a troca que um time faz em produção.
