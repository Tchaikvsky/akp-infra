terraform {
  required_version = ">= 1.5"

  required_providers {
    akp = {
      source  = "akuity/akp"
      version = "~> 0.10"
    }
  }
}

# Authentication is via environment variables — never put credentials in files:
#   export AKUITY_API_KEY_ID=...
#   export AKUITY_API_KEY_SECRET=...
provider "akp" {
  org_name = var.org_name
}
