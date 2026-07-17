output "argocd_cluster_ids" {
  description = "Argo CD cluster registration IDs, keyed by cluster name"
  value       = { for name, mod in module.cluster : name => mod.argocd_cluster_id }
}

output "kargo_agent_ids" {
  description = "Kargo agent IDs, keyed by cluster name"
  value       = { for name, mod in module.cluster : name => mod.kargo_agent_id }
}

output "kargo_default_shard" {
  description = "Cluster whose Kargo agent is the default shard (null if not set)"
  value       = var.kargo_default_shard
}
