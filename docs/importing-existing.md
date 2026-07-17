# Importing existing Akuity resources

You don't have to start from an empty organization. If you already created an
Argo CD instance, Kargo instance, or cluster registrations through the Akuity
UI, you can *adopt* them into these stacks with `terraform import` — Terraform
takes ownership of the existing resource instead of trying to create a
duplicate (which would fail on a name collision anyway).

## The workflow

Importing is always the same four-step loop, per resource:

### 1. Write the resource block first

Import attaches an existing object to a resource *address*, so the block must
exist before you import. Match the real-world settings as closely as you can —
anything that differs shows up as a change in the next plan.

For an existing Argo CD instance, that means editing `01-argocd/terraform.tfvars`
so `argocd_instance_name` (and `argocd_version`) match what's in the UI. For an
existing cluster, add an entry to the `clusters` map in `03-clusters`.

### 2. Find the import ID

Each resource type documents its import ID format in the **Import** section at
the bottom of its page in the
[provider registry docs](https://registry.terraform.io/providers/akuity/akp/latest/docs)
— check there rather than guessing, as formats can change between provider
versions:

- [`akp_instance`](https://registry.terraform.io/providers/akuity/akp/latest/docs/resources/instance)
- [`akp_kargo_instance`](https://registry.terraform.io/providers/akuity/akp/latest/docs/resources/kargo_instance)
- [`akp_cluster`](https://registry.terraform.io/providers/akuity/akp/latest/docs/resources/cluster)
- [`akp_kargo_agent`](https://registry.terraform.io/providers/akuity/akp/latest/docs/resources/kargo_agent)

Instance-scoped resources (clusters, agents) generally need a *composite* ID
that identifies both the parent instance and the child resource. Instance IDs
appear in the Akuity portal URL when you open the instance, and in
`terraform output` once the instance stacks are imported/applied.

### 3. Run the import

Shape-level examples (substitute the ID format from the registry docs):

```bash
# Adopt an existing Argo CD instance into stack 01
cd 01-argocd
terraform import akp_instance.argocd '<instance-import-id>'

# Adopt an existing Kargo instance into stack 02
cd ../02-kargo
terraform import akp_kargo_instance.kargo '<kargo-instance-import-id>'

# Adopt an existing cluster registration into stack 03
# (module resources use the full module address)
cd ../03-clusters
terraform import 'module.cluster["demo1"].akp_cluster.this' '<cluster-import-id>'
terraform import 'module.cluster["demo1"].akp_kargo_agent.this' '<agent-import-id>'
```

Terraform 1.5+ also supports declarative
[`import` blocks](https://developer.hashicorp.com/terraform/language/import)
(`import { to = ..., id = ... }`), which are plan-reviewable and repeatable —
worth using if you're importing many clusters.

### 4. Reconcile the plan to zero

```bash
terraform plan
```

- **No changes** — done; Terraform owns the resource.
- **In-place updates** — your config disagrees with reality. Usually the right
  fix is editing your config to match the platform, not letting Terraform
  "correct" a production instance on first contact. Read each diff.
- **Destroy/recreate** — stop. A forced replacement after import almost always
  means an immutable argument (like `name`) doesn't match. Fix the config;
  never apply a replacement you didn't intend.

## Import-specific gotchas in this repo

- **Passwords:** `argocd_secret` / `kargo_secret` are write-only from
  Terraform's perspective and covered by `ignore_changes`, so an imported
  instance keeps its existing admin password. To have Terraform manage it,
  rotate deliberately — see [day-2.md](day-2.md).
- **Kubeconfigs aren't imported:** for `module.cluster` imports you must still
  provide a working `kubeconfig_path` — the provider needs cluster access to
  manage the agent going forward.
- **The `kargo` wiring cluster:** if you previously connected Kargo to Argo CD
  via the UI, import that registration into `02-kargo`'s `akp_cluster.kargo`
  rather than letting Terraform create a second one.

## Verified import cheat sheet (provider v0.13.0)

| Resource | Import ID | Example |
|---|---|---|
| `akp_instance` | instance **name** | `terraform import akp_instance.argocd quickstart-argocd` |
| `akp_kargo_instance` | instance **name** | `terraform import akp_kargo_instance.kargo quickstart-kargo` |
| `akp_cluster` | `<argocd_instance_id>/<cluster_name>` | `terraform import 'module.cluster["c1"].akp_cluster.this' 7clec.../c1` |
| `akp_kargo_agent` | `<kargo_instance_id>/<agent_name>` | blocked — see known issues below |

Attributes that must be explicit in config or imports plan a REPLACE/UPDATE:

- `akp_cluster.spec.namespace_scoped = false` — **replacement-forcing** when
  left unset; always pin it.
- `spec.description = ""` and `spec.data.project = ""` — the platform
  normalizes unset strings to `""`.
- `spec.data.size` — match what the platform reports (e.g. `"auto"`), not
  what you assume.

## Known provider issues (observed with v0.13.0)

1. **`akp_kargo_agent` cannot be imported** when the org uses workspaces: the
   provider's workspace resolution scans workspaces instead of using the
   `workspace_id` already present in the instance response, queries the wrong
   workspace, and the resulting `PermissionDenied` is surfaced as
   "Cannot import non-existent remote object".
   **Workaround:** set `manage_kargo_agent = false` on the adopted cluster and
   leave the existing agent unmanaged.
2. **Updates to an imported `akp_cluster` can fail** with
   `invalid Cluster spec: parsing time "" as "2006-01-02T15:04:05Z07:00"` —
   the update RPC serializes an empty `maintenance_mode_expiry`.
   **Workaround:** set `adopted = true` on the cluster so the config exactly
   matches imported state (no kube_config, no ensure_healthy) and no update
   RPC is ever issued. Remove the flag once the provider is fixed and you
   want Terraform to manage agent manifests/kustomization.
