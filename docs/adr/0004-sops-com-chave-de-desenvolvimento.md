# ADR 0004: SOPS com chave de desenvolvimento no repositório

## Contexto

A senha do Grafana não pode ficar em texto puro no Git. Também não pode depender de um cofre pago, senão `make up` deixa de ser reproduzível.

## Decisão

O Secret está cifrado com SOPS e age em [platform/secrets/grafana-admin.yaml](../../platform/secrets/grafana-admin.yaml). A chave privada de desenvolvimento fica em [keys/dev.agekey](../../keys/dev.agekey). O Terraform decifra na hora do apply e cria o Secret no namespace `monitoring`. O chart do Grafana aponta para `existingSecret`.

## Consequências

Qualquer pessoa que clona o repositório lê a senha. Ela é `prumo-dev-admin` e serve só para esta demonstração. Em produção a chave privada fica fora do Git, num cofre ou em External Secrets, e o arquivo cifrado continua sendo a fonte. A cifra sem a chave no repositório é o padrão. A chave commitada é a exceção que torna o laboratório reproduzível, e está escrita aqui para não ser copiada sem essa ressalva.
