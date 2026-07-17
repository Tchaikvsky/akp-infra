# ── Argo CD instance ───────────────────────────────────────────────────────────
# A fully managed Argo CD control plane hosted on the Akuity Platform.
# No cluster is required to run it — workload clusters connect to it later
# (stack 03) via lightweight agents.

resource "akp_instance" "argocd" {
  name = var.argocd_instance_name

  argocd = {
    spec = {
      version = var.argocd_version
      instance_spec = {
        # Allows Argo CD system resources (config management plugins, AppProjects,
        # Applications in the control plane) to be managed declaratively from Git.
        # The akp-platform repo relies on this for its app-of-apps bootstrap.
        declarative_management_enabled = true
      }
    }
  }

  argocd_cm = {
    # Enable both API-key generation and UI login for the admin account.
    # API keys are needed later for CLI automation (argocd CLI, CI pipelines).
    "accounts.admin" = "apiKey,login"
  }

  argocd_secret = {
    "admin.password" = bcrypt(var.admin_password)
  }

  lifecycle {
    # GOTCHA: bcrypt() produces a different hash on every plan (it salts each
    # run), so without this the admin password would show as drift on every
    # apply. Ignore it after initial creation; see docs/day-2.md for how to
    # rotate the password deliberately.
    ignore_changes = [argocd_secret]
  }
}
