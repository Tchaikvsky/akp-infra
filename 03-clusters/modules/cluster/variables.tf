variable "name" {
  description = "Cluster name as it will appear in Argo CD and Kargo"
  type        = string
}

variable "kubeconfig_path" {
  description = "Path to a kubeconfig file with embedded client certificates for this cluster"
  type        = string
}

variable "kubeconfig_context" {
  description = "Kubeconfig context to use. Defaults to the file's current-context, then the first context."
  type        = string
  default     = null
}

variable "size" {
  description = "Akuity agent size (small, medium, large)"
  type        = string
  default     = "small"
}

variable "labels" {
  description = "Argo CD cluster labels. Add ApplicationSet-triggering labels (e.g. fleet=true) only after the agent is healthy — see two-phase registration note in main.tf."
  type        = map(string)
  default     = {}
}

variable "tune_agent_resources" {
  description = "Apply the kustomization patch that shrinks agent CPU requests — recommended for small/local clusters (k3d, kind, minikube)"
  type        = bool
  default     = false
}

variable "adopted" {
  description = "This cluster was registered outside Terraform and imported. Skips the agent-install kubeconfig and health gating so adoption requires no update RPC (works around provider update bugs on imported clusters — see docs/importing-existing.md)."
  type        = bool
  default     = false
}

variable "manage_kargo_agent" {
  description = "Manage this cluster's Kargo agent with Terraform. Set false to adopt a cluster whose agent already exists outside Terraform (see docs/importing-existing.md)."
  type        = bool
  default     = true
}

variable "kargo_agent_name" {
  description = "Name for the Kargo agent. Defaults to the cluster name; override when adopting an existing agent registered under a different name."
  type        = string
  default     = null
}

variable "kustomization_path" {
  description = "Path to the kustomization.yaml applied to agent manifests when tune_agent_resources is true"
  type        = string
}

variable "argocd_instance_id" {
  description = "ID of the Akuity Argo CD instance to register this cluster with"
  type        = string
}

variable "kargo_instance_id" {
  description = "ID of the Akuity Kargo instance to register this cluster's Kargo agent with"
  type        = string
}
