# ADR 0002: Terraform only bootstraps

## Context

You can describe a Deployment, an Ingress, and a Helm release in Terraform. Every tag change then becomes an apply, a state update, and a blast radius larger than the change needs.

## Decision

Terraform creates the cluster, loads the local image, installs Argo CD, starts the git daemon, and writes the Grafana Secret. Everything else lives in Git and is applied by Argo CD.

## Consequences

There is a clear line to explain: infrastructure changes rarely and has state; the application changes often and has reconciliation. Terraform state does not hold the workload deploy history.
