output "argocd_url" {
  description = "Argo CD UI URL (Akuity-provided subdomain)"
  value       = "https://${akp_instance.argocd.id}.cd.akuity.cloud"
}

output "argocd_instance_id" {
  description = "Akuity Argo CD instance ID"
  value       = akp_instance.argocd.id
}

output "argocd_instance_name" {
  description = "Instance name — stacks 02 and 03 look the instance up by this name"
  value       = akp_instance.argocd.name
}
