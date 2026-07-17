output "argocd_cluster_id" {
  description = "Argo CD cluster registration ID"
  value       = akp_cluster.this.id
}

output "kargo_agent_id" {
  description = "Kargo agent ID — used by the root stack to set the default shard. Null when manage_kargo_agent = false."
  value       = try(akp_kargo_agent.this[0].id, null)
}
