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

# User variables of the machinepool role, alphabetical. Set them through
# TerraformMachinePool spec.variables or spec.variablesFrom
# (https://captf.io/docs/user-guide/variables.html).

variable "accelerated_networking" {
  description = "Enable accelerated networking on the instances' NICs. On by default because the default size supports it; turn it off for a vm_size that does not."
  type        = bool
  default     = true
  nullable    = false
}

variable "additional_tags" {
  description = "Extra Azure tags on every taggable resource. The captf.io_* tags always win: keys that collide with them are rejected."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    # Azure tag names are case-insensitive, so the check is too.
    condition     = alltrue([for k in keys(var.additional_tags) : !can(regex("(?i)^captf\\.io[_/]", k))])
    error_message = "additional_tags must not use keys starting with captf.io_ or captf.io/: they are reserved for the captf_tags the controller sets."
  }
  validation {
    # https://learn.microsoft.com/azure/azure-resource-manager/management/tag-resources#limitations
    condition     = alltrue([for k, v in var.additional_tags : length(k) >= 1 && length(k) <= 512 && length(v) <= 256 && !can(regex("[<>%&\\\\?/]", k))])
    error_message = "additional_tags keys must be 1-512 characters without < > % & \\ ? /, and values at most 256 characters (Azure tag limits)."
  }
  validation {
    # Azure allows 50 tags per resource; the six captf tags take six.
    condition     = length(var.additional_tags) <= 44
    error_message = "additional_tags may hold at most 44 tags: Azure allows 50 per resource and the captf tags use 6."
  }
}

variable "autoscaling_scale_in_cpu_percent" {
  description = "With autoscaling enabled, scale in (one instance fewer) below this average CPU percentage over 10 minutes. 25 by default: a wide band between the two thresholds keeps the pool from flapping."
  type        = number
  default     = 25
  nullable    = false

  validation {
    condition     = var.autoscaling_scale_in_cpu_percent == floor(var.autoscaling_scale_in_cpu_percent) && var.autoscaling_scale_in_cpu_percent >= 1 && var.autoscaling_scale_in_cpu_percent <= 100
    error_message = "autoscaling_scale_in_cpu_percent must be a whole number from 1 to 100."
  }
}

variable "autoscaling_scale_out_cpu_percent" {
  description = "With autoscaling enabled, scale out (one instance more) above this average CPU percentage over 10 minutes. 75 by default: a wide band between the two thresholds keeps the pool from flapping."
  type        = number
  default     = 75
  nullable    = false

  validation {
    condition     = var.autoscaling_scale_out_cpu_percent == floor(var.autoscaling_scale_out_cpu_percent) && var.autoscaling_scale_out_cpu_percent >= 1 && var.autoscaling_scale_out_cpu_percent <= 100
    error_message = "autoscaling_scale_out_cpu_percent must be a whole number from 1 to 100."
  }
}

variable "boot_diagnostics" {
  description = "Keep the serial console log in Azure-managed storage, for debugging a node that never joins. The log shows boot output, which may include kubeadm's join command."
  type        = bool
  default     = true
  nullable    = false
}

variable "encryption_at_host" {
  description = "Encrypt temporary disks and caches on the host too. Off by default because it needs the EncryptionAtHost feature registered on the subscription; managed disks are encrypted at rest either way."
  type        = bool
  default     = false
  nullable    = false
}

variable "external_cluster_exports" {
  description = "The exports (schema captf.io/azure-cluster/v1) to use when the TerraformCluster is externally managed and captf_cluster_outputs is {}."
  type        = any
  default     = null

  validation {
    condition     = var.external_cluster_exports == null || try(var.external_cluster_exports.schema == "captf.io/azure-cluster/v1", false)
    error_message = "external_cluster_exports must follow schema captf.io/azure-cluster/v1 (README \"Exports\"), or be null."
  }
}

variable "image_id" {
  description = "Image of the instances: a managed image, a Compute Gallery image (version) or a community gallery image (version) ID. {version} and {semver} become the pool's version (v1.31.4 and 1.31.4, without any +suffix). Required: Kubernetes nodes need an image with kubeadm and the kubelet. A change applies to new instances only."
  type        = string
  default     = null

  validation {
    # The forms azurerm 5.7.0 accepts for source_image_id; community and
    # shared gallery IDs are case-sensitive there.
    condition = var.image_id != null && (
      can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Compute/(images/[^/]+|galleries/[^/]+/images/[^/]+(/versions/[^/]+)?)$", var.image_id)) ||
      can(regex("^/(communityGalleries|sharedGalleries)/[^/]+/images/[^/]+(/versions/[^/]+)?$", var.image_id))
    )
    error_message = "image_id must be set (spec.variables.image_id) to a managed image, gallery image or gallery image version ID, for example /communityGalleries/ClusterAPI-f72ceb4f-5159-4c26-a0fe-2ea738f0d019/images/capi-ubun2-2404/versions/{semver}."
  }
}

variable "ip_forwarding" {
  description = "Let the NICs forward traffic for addresses that are not its own, which CNIs that route pod addresses natively need. Off by default: overlay CNIs do not."
  type        = bool
  default     = false
  nullable    = false
}

variable "os_disk_size_gib" {
  description = "Size of each instance's OS disk in GiB. 128 leaves room for images and logs."
  type        = number
  default     = 128
  nullable    = false

  validation {
    condition     = var.os_disk_size_gib == floor(var.os_disk_size_gib) && var.os_disk_size_gib >= 30 && var.os_disk_size_gib <= 4095
    error_message = "os_disk_size_gib must be a whole number from 30 to 4095."
  }
}

variable "os_disk_storage_account_type" {
  description = "Storage type of the OS disks. Premium_LRS by default; it needs a vm_size with premium storage (an s in the size name). A change replaces the scale set."
  type        = string
  default     = "Premium_LRS"
  nullable    = false

  validation {
    condition     = contains(["Standard_LRS", "StandardSSD_LRS", "StandardSSD_ZRS", "Premium_LRS", "Premium_ZRS"], var.os_disk_storage_account_type)
    error_message = "os_disk_storage_account_type must be one of Standard_LRS, StandardSSD_LRS, StandardSSD_ZRS, Premium_LRS, Premium_ZRS."
  }
}

variable "spot" {
  description = "Run Spot instances, deleted on eviction so they leave the pool's membership. A change replaces the scale set."
  type        = bool
  default     = false
  nullable    = false
}

variable "trusted_launch" {
  description = "Turn on secure boot and vTPM. Off by default because it needs a generation 2 image built for trusted launch, which the CAPZ reference images are not. A change replaces the scale set."
  type        = bool
  default     = false
  nullable    = false
}

variable "vm_size" {
  description = "Azure VM size of the instances. Standard_D4s_v5 (4 vCPU, 16 GiB) by default, like the machine role. A change applies to new instances only."
  type        = string
  default     = "Standard_D4s_v5"
  nullable    = false

  validation {
    condition     = can(regex("^(Standard|Basic)_[A-Za-z0-9_-]+$", var.vm_size))
    error_message = "vm_size must be an Azure VM size name such as Standard_D4s_v5."
  }
}
