terraform {
  required_version = ">= 1.9"

  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.104"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.9"
    }
  }
}

# Token from the environment, never from a file in git:
#   export DIGITALOCEAN_TOKEN=dop_v1_...
provider "digitalocean" {}
