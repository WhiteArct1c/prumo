# Development key

`dev.agekey` opens the files encrypted with SOPS in this repository.

It is in Git on purpose: without it, `make up` does not come up on a new machine. The password it protects is the Grafana demo password. Do not use this key outside this lab. [ADR 0004](../docs/adr/0004-sops-with-a-dev-key.md) explains the swap a team makes in production.
