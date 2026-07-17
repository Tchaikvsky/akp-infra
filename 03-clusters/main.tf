# ── Look up the control-plane instances from stacks 01 and 02 ──────────────────
# Stacks are wired together by instance NAME via provider data sources, not
# terraform_remote_state — each stack stays independently applyable.

data "akp_instance" "argocd" {
  name = var.argocd_instance_name
}

data "akp_kargo_instance" "kargo" {
  name = var.kargo_instance_name
}

# ── Workload clusters ──────────────────────────────────────────────────────────
# One module instance per cluster. Each registration installs TWO agents into
# the cluster (namespace "akuity"):
#   - the Argo CD agent — pulls desired state from the hosted Argo CD instance
#     and applies it in-cluster (no inbound access to your cluster needed)
#   - the Kargo agent   — watches Warehouses/Stages and executes promotions,
#     linked back to Argo CD so promotions can trigger syncs

module "cluster" {
  for_each = var.clusters
  source   = "./modules/cluster"

  name                 = each.key
  kubeconfig_path      = each.value.kubeconfig_path
  kubeconfig_context   = each.value.kubeconfig_context
  size                 = each.value.size
  labels               = each.value.labels
  tune_agent_resources = each.value.tune_agent_resources
  kargo_agent_name     = each.value.kargo_agent_name
  manage_kargo_agent   = each.value.manage_kargo_agent
  adopted              = each.value.adopted
  kustomization_path   = "${path.module}/templates/kustomization.yaml"

  argocd_instance_id = data.akp_instance.argocd.id
  kargo_instance_id  = data.akp_kargo_instance.kargo.id
}

# ── Kargo default shard (optional) ─────────────────────────────────────────────
# Lives here rather than in 02-kargo because it must point at a registered
# workload-cluster agent, which only exists after this stack applies.

resource "akp_kargo_default_shard_agent" "default" {
  count = var.kargo_default_shard == null ? 0 : 1

  kargo_instance_id = data.akp_kargo_instance.kargo.id
  agent_id          = module.cluster[var.kargo_default_shard].kargo_agent_id

  depends_on = [module.cluster]
}
