locals {
  cf_domain = "tas.${var.base_domain}"
}

module "system_cert" {
  source = "git::https://github.com/pacphi/tf4k8s.git//modules/acme/aws"

  dns_zone_id = var.dns_zone_id
  email = var.email
  common_name = "*.${local.cf_domain}"
  additional_domains = [ "*.login.${local.cf_domain}", "*.uaa.${local.cf_domain}" ]
}

module "workloads_cert" {
  source = "git::https://github.com/pacphi/tf4k8s.git//modules/acme/aws"

  dns_zone_id = var.dns_zone_id
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

data "aws_s3_bucket" "certs_and_keys_bucket" {
  bucket = "tf4k8s-pipelines-config"
}

resource "aws_s3_bucket_object" "certs_and_keys" {
  bucket = data.aws_s3_bucket.certs_and_keys_bucket.id
  key    = var.path_to_certs_and_keys
  source = local_file.certs_var_file.filename
}

variable "email" {
  description = "Email address of base domain owner"
}

variable "base_domain" {
   description = "An existing domain wherein a number of *.tas.<domain> wildcard domain recordsets will be made available"
}

variable "path_to_certs_and_keys" {
  description = "The path underneath the Amazon S3 bucket where the certs-and-keys.vars file will be stored."
}

variable "dns_zone_id" {
  description = "The DNS zone identifier within Amazon Route53 that defines the base domain as an NS record."
}

variable "region" {
  description = "The AWS region where an S3 bucket resides to capture certificates and keys in a file (e.g., us-west-2)"
}

provider "aws" {
  version = ">=3.9.0"
  region = var.region
}