# Day 2 — operating the platform layer

You've applied all three stacks. This guide covers the routine operations:
detecting drift, upgrading instance versions, rotating passwords, growing and
shrinking the fleet, and moving off local state.

## Drift detection

Because the Akuity UI remains fully functional, out-of-band changes are always
possible. Make `terraform plan` your drift detector:

```bash
for d in 01-argocd 02-kargo 03-clusters; do
  (cd "$d" && terraform plan -detailed-exitcode)
done
```

`-detailed-exitcode` returns `0` for no changes, `2` for pending changes —
easy to wire into CI as a scheduled job.

Two places are *intentionally* blind to drift (see the `lifecycle` blocks):

- `argocd_secret` / `kargo_secret` — bcrypt hashes differ every run, so
  password drift is invisible to plan. Rotate deliberately (below).
- `kargo.spec.version` in 02 — the platform may bump patch versions
  server-side; ignoring it stops Terraform from fighting the platform.

## Instance version upgrades

**Argo CD (01):** set `argocd_version` (tfvars or variable default), then
`terraform plan` / `apply`. Review Akuity's release notes for the target
`vX.Y.Z-ak.N` build first; upgrades roll through the hosted control plane and
then the agents.

**Kargo (02):** the version is under `ignore_changes`, so a tfvars bump alone
is a no-op. To upgrade deliberately:

1. Temporarily remove `kargo.spec.version` from the `ignore_changes` list in
   `02-kargo/main.tf`.
2. Set the new `kargo_version` and apply.
3. Restore the `ignore_changes` entry.

Upgrade one environment at a time and verify agents reconnect (Kargo UI →
Agents) before proceeding.

## Password rotation

The admin secrets are under `ignore_changes` (bcrypt is non-deterministic), so
changing `TF_VAR_admin_password` does nothing by itself. To rotate:

```bash
export TF_VAR_admin_password='<new password>'

# Force re-application of just the secret-bearing resource:
cd 01-argocd
terraform apply -replace=akp_instance.argocd    # heavy: recreates the instance
```

Recreating an instance to rotate a password is usually overkill. Lighter
options, in order of preference:

1. Rotate via the Akuity portal / Argo CD `argocd account update-password`,
   then update your env var to match. Terraform stays silent because of
   `ignore_changes` — this is the intended workflow.
2. Temporarily comment out the `ignore_changes` entry, apply (updates the hash
   in place), restore it. Expect a plan diff every run while it's commented
   out.

Longer term, prefer SSO for humans and API keys for automation over shared
admin passwords; the admin account here is a bootstrap convenience.

## Adding a cluster safely

1. Get a kubeconfig with embedded client certs (gitignored `.kubeconfigs/` is
   the conventional spot).
2. Add an entry to the `clusters` map in `03-clusters/terraform.tfvars` —
   **without** any ApplicationSet-triggering labels:

   ```hcl
   demo2 = {
     kubeconfig_path      = ".kubeconfigs/demo2.yaml"
     tune_agent_resources = true
   }
   ```

3. `terraform apply` — it blocks until the agents are healthy
   (`ensure_healthy = true`). If it hangs, check `kubectl -n akuity get pods`
   on the new cluster; on small clusters, Pending agent pods usually mean you
   want `tune_agent_resources = true`.
4. **Phase two:** once healthy, add labels (e.g. `labels = { fleet = "true" }`)
   and apply again. Now ApplicationSets in akp-platform pick the cluster up
   and addons land on a cluster whose agent can actually sync them.

## Removing a cluster safely

Order matters — drain the GitOps layer before pulling the platform layer:

1. Remove the cluster from akp-platform's generators (delete its `fleet`
   label first if labels drive them, or remove its stage/env config) and let
   Argo CD prune the apps.
2. If it's the `kargo_default_shard`, point that variable at another cluster
   and apply.
3. Delete the entry from the `clusters` map and `terraform apply`. This
   deregisters the cluster and uninstalls the agents. If the cluster is
   already gone/unreachable, the provider can't clean up in-cluster resources
   — expect to `terraform state rm 'module.cluster["<name>"]...'` and remove
   the registration in the Akuity portal.

## Migrating to remote state

Local state files contain secrets (instance settings, kube credentials in
resource attributes) and don't support locking or collaboration. To migrate a
stack, add a backend to its `providers.tf`:

```hcl
terraform {
  backend "s3" {
    bucket       = "your-tf-state"
    key          = "akp-infra/01-argocd/terraform.tfstate"
    region       = "us-west-2"
    use_lockfile = true
  }
}
```

Then, in that stack:

```bash
terraform init -migrate-state   # copies local state into the backend
```

Repeat per stack (each keeps its own state key). After confirming
`terraform plan` is clean against the remote backend, delete the local
`terraform.tfstate*` files. Any backend works (GCS, azurerm, HCP Terraform) —
see the [backend docs](https://developer.hashicorp.com/terraform/language/backend).
