## Verifying Images

Verify a CI-built image with cosign:

```bash
cosign verify ${GHCR_BASE}/<app>:<sha> \
  --certificate-identity-regexp ".+" \
  --certificate-oidc-issuer https://token.actions.githubusercontent.com
```

## Operations

**Force a sync during debugging:** the local KinD cluster has no GitHub webhook receiver, so use ArgoCD as the escape hatch when you do not want to wait for polling:

```bash
argocd app sync <app>
```

**Rotate GitHub App credentials:** edit `terraform/terraform.tfvars`, re-apply Terraform, then restart Backstage so envFrom values are re-read:

```bash
cd terraform && terraform apply
kubectl rollout restart deployment/backstage -n backstage
```

**Future migration path:** Terraform-managed Secrets are the local-development bootstrap path. ExternalSecrets Operator is the planned migration when production or shared cloud secret stores arrive.

## Useful Commands

```bash
# View ArgoCD Applications
kubectl get applications -n argocd

# View pod logs
kubectl logs -n backstage -l app.kubernetes.io/name=backstage

# View pod logs with timestamps
kubectl logs -n backstage deploy/backstage --timestamps

# Restart deployment
kubectl rollout restart deployment backstage -n backstage

# Check Gateway status
kubectl get gateway -n gateway
kubectl get httproute -n backstage
kubectl get httproute -n argocd

# View Envoy Gateway controller logs
kubectl logs -n envoy-gateway-system deploy/envoy-gateway

# View all resources in the namespace
kubectl get all -n backstage

# Tear down the cluster
cd terraform && terraform destroy
```
