# Copyright 2026 The CAPTF Authors.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# The pool: one uniform Linux scale set with manual upgrades (DESIGN.md
# decision 7). A bootstrap rotation updates its model in place; a
# Kubernetes version change creates a new scale set (locals_names.tf).
resource "azurerm_linux_virtual_machine_scale_set" "pool_scale_set" {
  count = local.exports_available ? 1 : 0

  admin_username                  = local.admin_username
  computer_name_prefix            = local.scale_set_name
  custom_data                     = local.custom_data
  disable_password_authentication = true
  encryption_at_host_enabled      = var.encryption_at_host
  # Evicted Spot instances are deleted, so they leave the membership and
  # the capacity scaler (Azure Autoscale or an outside one) replaces them.
  eviction_policy = var.spot ? "Delete" : null
  # No VM extensions: nothing here needs one, and each is code running as root.
  extension_operations_enabled = false
  # The initial capacity; Azure Autoscale or, with autoscaler external, an
  # outside scaler owns it afterwards (pool_autoscale_setting.tf).
  instances = local.desired_replicas
  location  = local.location
  # -1: pay up to the on-demand price; Azure then evicts for capacity only.
  max_bid_price = var.spot ? -1 : null
  name          = local.scale_set_name
  # Extra instances would run the bootstrap data and join as Nodes.
  overprovision       = false
  priority            = var.spot ? "Spot" : "Regular"
  provision_vm_agent  = true
  resource_group_name = local.resource_group_name
  secure_boot_enabled = var.trusted_launch
  # Lets the pool grow past 100 instances.
  single_placement_group = false
  sku                    = var.vm_size
  source_image_id        = local.image_id
  tags                   = local.tags
  # Manual: Azure never upgrades instances by itself.
  upgrade_mode = "Manual"
  vtpm_enabled = var.trusted_launch
  # Strict balancing would block a scale-out while one zone lacks capacity.
  zone_balance = false
  zones        = length(local.zones) > 0 ? local.zones : null

  admin_ssh_key {
    public_key = local.admin_ssh_public_key
    username   = local.admin_username
  }

  # Azure-managed storage: no storage account to bring.
  dynamic "boot_diagnostics" {
    for_each = var.boot_diagnostics ? [true] : []

    content {}
  }

  identity {
    identity_ids = [local.identity_id]
    type         = "UserAssigned"
  }

  network_interface {
    accelerated_networking_enabled = var.accelerated_networking
    ip_forwarding_enabled          = var.ip_forwarding
    name                           = local.network_interface_name
    network_security_group_id      = local.security_group_id
    primary                        = true

    ip_configuration {
      application_security_group_ids = [local.application_security_group_id]
      name                           = local.network_interface_name
      primary                        = true
      subnet_id                      = local.subnet_id
      version                        = "IPv4"
    }
  }

  os_disk {
    caching              = "ReadWrite"
    disk_size_gb         = var.os_disk_size_gib
    storage_account_type = var.os_disk_storage_account_type
  }

  # Scheduled Events announce a deletion 5 minutes ahead, so a termination
  # handler can drain the Node: pools get no CAPI drain
  # (machinepool.md, "MachinePool Machines ... are out of scope").
  termination_notification {
    enabled = true
    timeout = "PT5M"
  }

  lifecycle {
    # A new generation (locals_names.tf) runs before the old one is deleted.
    create_before_destroy = true
    # Azure Autoscale, or an outside scaler with autoscaler external, owns
    # the capacity; an apply must never reset it (machinepool.md
    # "autoscaling (input)").
    ignore_changes = [instances]

    # Checks that span variables (CONVENTIONS.md section 4).
    precondition {
      condition     = alltrue([for z in local.zones : contains(local.cluster_zone_names, z)])
      error_message = "failure_domains ${join(", ", local.zones)} are not all failure domains of the cluster (${length(local.cluster_zone_names) > 0 ? join(", ", local.cluster_zone_names) : "none: the region has no availability zones"})."
    }
    precondition {
      condition     = !local.image_uses_kubernetes_version || local.kubernetes_semver != null
      error_message = "image_id contains {version} or {semver}, but the MachinePool has no spec.template.spec.version: set the version, or a fixed image_id."
    }
    precondition {
      condition     = var.bootstrap_format == "cloud-config" || length(local.node_labels) == 0
      error_message = "node_labels need cloud-config bootstrap data: an Ignition payload cannot be extended without parsing it. Remove the MachinePool's template labels (other than those NodeRestriction forbids, which are dropped anyway), or use cloud-config."
    }
    precondition {
      condition     = !(var.bootstrap_format == "ignition" && local.bootstrap_gzipped)
      error_message = "bootstrap_data is gzipped Ignition, which this module rejects (CONVENTIONS.md section 13): turn off gzipUserData for Ignition."
    }
    precondition {
      condition     = length(local.custom_data) <= local.custom_data_max_length
      error_message = "The custom data is ${nonsensitive(length(local.custom_data))} base64 characters, more than Azure's ${local.custom_data_max_length} (64 KiB): compress the bootstrap data (CAPRKE2 gzipUserData) or make it smaller."
    }
  }
}
