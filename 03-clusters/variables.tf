variable "org_name" {
  description = "Akuity Platform organization name"
  type        = string
}

variable "argocd_instance_name" {
  description = "Name of the Argo CD instance created by stack 01-argocd (looked up by name — no remote state needed)"
  type        = string
  default     = "quickstart-argocd"
}

variable "kargo_instance_name" {
  description = "Name of the Kargo instance created by stack 02-kargo (looked up by name — no remote state needed)"
  type        = string
  default     = "quickstart-kargo"
}

variable "clusters" {
  description = <<-EOT
    Workload clusters to register, keyed by cluster name.

    Per cluster:
      kubeconfig_path      — path to a kubeconfig file for the cluster (required).
                             Must use embedded client certificates; see the note
                             in modules/cluster/main.tf about exec-plugin
                             kubeconfigs (EKS/GKE/AKS).
      kubeconfig_context   — context to use; defaults to the file's
                             current-context, then the first context.
      size                 — Akuity agent size (default "small").
      labels               — Argo CD cluster labels. GOTCHA: register the
                             cluster with no fleet/addon labels first, confirm
                             the agent is healthy, THEN add labels that trigger
                             ApplicationSet generators (two-phase registration —
                             otherwise apps race a half-installed agent).
      tune_agent_resources — apply templates/kustomization.yaml to shrink agent
                             CPU requests. Recommended for small/local clusters
                             (k3d, kind, minikube) where default requests can
                             leave agent pods Pending.
  EOT
  type = map(object({
    kubeconfig_path      = string
    kubeconfig_context   = optional(string)
    size                 = optional(string, "small")
    labels               = optional(map(string), {})
    tune_agent_resources = optional(bool, false)
    # Kargo agent name; defaults to the cluster name. Override when adopting
    # an existing agent that was registered under a different name.
    kargo_agent_name = optional(string)
    # Set false to leave a pre-existing Kargo agent unmanaged (adoption
    # escape hatch — see docs/importing-existing.md).
    manage_kargo_agent = optional(bool, true)
    # Cluster registered outside Terraform and imported: skip the
    # agent-install kubeconfig and health gating so no update RPC is issued
    # (see docs/importing-existing.md).
    adopted = optional(bool, false)
  }))
}

variable "kargo_default_shard" {
  description = <<-EOT
    Optional: name of the cluster (a key of var.clusters) whose Kargo agent
    becomes the default shard — i.e. where Kargo runs promotion processes when
    a Stage doesn't specify a shard. Leave null to skip.
  EOT
  type        = string
  default     = null
}
