locals {
  cf_domain = "tas.${var.base_domain}"
}

module "system_cert" {
  source = "git::https://github.com/pacphi/tf4k8s.git//modules/acme/azure"

  client_id = var.client_id
  client_secret = var.client_secret
  tenant_id = var.tenant_id
  subscription_id = var.subscription_id
  resource_group_name = var.resource_group_name
  email = var.email
  common_name = "*.${local.cf_domain}"
  additional_domains = [ "*.login.${local.cf_domain}", "*.uaa.${local.cf_domain}" ]
}

module "workloads_cert" {
  source = "git::https://github.com/pacphi/tf4k8s.git//modules/acme/azure"

  client_id = var.client_id
  client_secret = var.client_secret
  tenant_id = var.tenant_id
  subscription_id = var.subscription_id
  resource_group_name = var.resource_group_name
  email = var.email
  common_name = "*.apps.${local.cf_domain}"
}

data "template_file" "certs_var_file" {
  template = file("${path.module}/certs-and-keys.tpl")
  
  vars = {
    system_fullchain_certificate = trim(base64encode(module.system_cert.cert_full_chain), "\n")
    system_private_key = trim(base64encode(module.system_cert.cert_key), "\n")
    workloads_fullchain_certificate = trim(base64encode(module.workloads_cert.cert_full_chain), "\n")
    workloads_private_key = trim(base64encode(module.workloads_cert.cert_key), "\n")
  }
}

resource "local_file" "certs_var_file" {
  content  = data.template_file.certs_var_file.rendered
  filename = "/tmp/certs-and-keys.vars"
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

data "azurerm_storage_account" "sac" {
  name                     = var.storage_account_name
  resource_group_name      = data.azurerm_resource_group.rg.name
}

data "azurerm_storage_container" "sc" {
  name                  = "tf4k8s-pipelines-config"
  storage_account_name  = data.azurerm_storage_account.sac.name
}

resource "azurerm_storage_blob" "certs_and_keys" {
  name                   = var.path_to_certs_and_keys
  storage_account_name   = data.azurerm_storage_account.sac.name
  storage_container_name = data.azurerm_storage_container.sc.name
  type                   = "Block"
  source                 = local_file.certs_var_file.filename
}

variable "email" {
  description = "Email address of base domain owner"
}

variable "base_domain" {
   description = "An existing domain wherein a number of *.tas.<domain> wildcard domain recordsets will be made available"
}

variable "path_to_certs_and_keys" {
  description = "The path underneath the Azure Blob Storage container where the certs-and-keys.vars file will be stored."
}

variable "resource_group_name" {
  description = "A nrame for a resource group; @see https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/manage-resource-groups-portal#what-is-a-resource-group"
}

variable "storage_account_name" {
  description = "Specifies the storage account with which to reference/create a storage container"
}

variable "client_id" {
  description = "Azure Service Principal appId"
}

variable "client_secret" {
  description = "Azure Service Principal password"
}

variable "subscription_id" {
  description = "Azure Subscription id"
}

variable "tenant_id" {
  description = "Azure Service Principal tenant"
}

provider "azurerm" {
  version = ">=2.30.0"
  client_id = var.client_id
  subscription_id = var.subscription_id
  tenant_id = var.tenant_id
  client_secret = var.client_secret
  features {}
}