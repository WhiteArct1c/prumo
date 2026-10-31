# ADR 0004: SOPS with a development key in the repository

## Context

The Grafana password cannot sit in Git as plaintext. It also cannot depend on a paid vault, or `make up` stops being reproducible.

## Decision

The Secret is encrypted with SOPS and age in [platform/secrets/grafana-admin.yaml](../../platform/secrets/grafana-admin.yaml). The development private key lives in [keys/dev.agekey](../../keys/dev.agekey). Terraform decrypts it at apply time and creates the Secret in the `monitoring` namespace. The Grafana chart points at `existingSecret`.

## Consequences

Anyone who clones the repository can read the password. It is `prumo-dev-admin` and exists only for this demo. In production the private key stays out of Git, in a vault or in External Secrets, and the encrypted file remains the source. Encryption without the key in the repository is the default. The committed key is the exception that makes the lab reproducible, and it is written here so it is not copied without that caveat.
