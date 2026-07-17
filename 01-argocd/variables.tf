variable "org_name" {
  description = "Akuity Platform organization name"
  type        = string
}

variable "argocd_instance_name" {
  description = "Name for the Argo CD instance on the Akuity Platform"
  type        = string
  default     = "quickstart-argocd"
}

variable "argocd_version" {
  description = "Argo CD version to deploy (Akuity build, e.g. v3.4.3-ak.92)"
  type        = string
  default     = "v3.4.3-ak.92"
}

variable "admin_password" {
  description = <<-EOT
    Admin password for the Argo CD instance.
    Set via environment variable to keep it out of files:
      export TF_VAR_admin_password="..."
  EOT
  type        = string
  sensitive   = true
}
