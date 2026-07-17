output "kargo_url" {
  description = "Kargo UI URL (Akuity-provided subdomain)"
  value       = "https://${akp_kargo_instance.kargo.id}.kargo.akuity.cloud"
}

output "kargo_instance_id" {
  description = "Akuity Kargo instance ID"
  value       = akp_kargo_instance.kargo.id
}

output "kargo_instance_name" {
  description = "Instance name — stack 03 looks the instance up by this name"
  value       = akp_kargo_instance.kargo.name
}

output "kargo_argocd_cluster_name" {
  description = "Name of the Argo CD cluster destination backed by the Kargo control plane"
  value       = akp_cluster.kargo.name
}
