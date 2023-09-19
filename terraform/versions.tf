terraform {
  backend "remote" {
    organization = "birki-io"

    workspaces {
      name = "ghostfolio"
    }
  }

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "3.73.0"
    }
  }

  required_version = "=1.5.7" # Change this to a different version if you want
}
