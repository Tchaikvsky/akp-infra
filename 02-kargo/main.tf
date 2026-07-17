# ── Look up the Argo CD instance from stack 01 ─────────────────────────────────
# Stacks are wired together by instance NAME via provider data sources, not
# terraform_remote_state — each stack stays independently applyable as long as
# the previous one exists on the platform.

data "akp_instance" "argocd" {
  name = var.argocd_instance_name
}

# ── Kargo instance ─────────────────────────────────────────────────────────────
# A fully managed Kargo control plane hosted on the Akuity Platform.
# Kargo orchestrates promotions (dev -> staging -> prod) by writing to Git;
# Argo CD then syncs what Kargo promoted.

resource "akp_kargo_instance" "kargo" {
  name      = var.kargo_instance_name
  workspace = "default"

  kargo = {
    spec = {
      version = var.kargo_version
      kargo_instance_spec = {
        # Whether to run the promotion controller on the Akuity-hosted control
        # plane (promotions work before any self-hosted agent is registered).
        # Set false if your agents run promotions — an agent integrated with
        # Argo CD is required either way for argocd-update steps; see 03.
        promo_controller_enabled = var.promo_controller_enabled
      }
    }
  }

  kargo_cm = {
    adminAccountEnabled  = "true"
    adminAccountTokenTtl = "24h"
  }

  kargo_secret = {
    adminAccountPasswordHash = bcrypt(var.admin_password)
  }

  lifecycle {
    # GOTCHA:
    # - bcrypt() produces a different hash on every plan (it salts each run),
    #   so kargo_secret would otherwise show drift on every apply.
    # - The platform can bump the Kargo patch version server-side; ignoring
    #   kargo.spec.version avoids fighting it. To upgrade deliberately, see
    #   docs/day-2.md.
    ignore_changes = [kargo.spec.version, kargo_secret]
  }
}

# ── Register the Kargo control plane in Argo CD as cluster "kargo" ─────────────
# This is the wiring step that makes the two instances a single system:
# it registers the Kargo control plane itself as an Argo CD cluster
# destination named "kargo", giving Argo CD declarative write access to
# Kargo's API. From then on, Kargo Projects / Warehouses / Stages can be
# managed via GitOps — the akp-platform repo's kargo-apps ApplicationSet
# targets exactly this destination to deploy Kargo pipeline definitions.
#
# No kubeconfig is needed: direct_cluster_spec with cluster_type = "kargo"
# tells the platform to connect the two hosted control planes internally.

resource "akp_cluster" "kargo" {
  instance_id = data.akp_instance.argocd.id
  name        = "kargo"
  namespace   = "akuity"

  spec = {
    # Explicit rather than defaulted: this attribute forces REPLACEMENT when
    # it differs, and the platform stores `false` — leaving it unset makes
    # `terraform import` of an existing registration plan a destroy/recreate.
    namespace_scoped = false
    # The platform normalizes unset strings to "" — explicit "" (here and on
    # data.project below) keeps imported resources at zero diff.
    description = ""

    data = {
      direct_cluster_spec = {
        kargo_instance_id = akp_kargo_instance.kargo.id
        cluster_type      = "kargo"
      }
      size    = "small"
      project = ""
    }
  }

  depends_on = [akp_kargo_instance.kargo]
}

# NOTE: the Kargo *default shard* (which agent runs promotions by default) is
# configured in stack 03-clusters via akp_kargo_default_shard_agent, because it
# must reference a registered workload-cluster agent that does not exist yet.
