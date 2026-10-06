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

# Contract inputs of the machinepool role, v1alpha1, in contract order and
# with the contract's types
# (https://captf.io/docs/module-author/contract/v1alpha1/machinepool.html#inputs).

# Read only by its own validation.
# tflint-ignore: terraform_unused_declarations
variable "captf_contract" {
  description = "Contract version the controller generated the root module for (common.md \"Inputs\")."
  type        = string

  validation {
    condition     = var.captf_contract == "v1alpha1"
    error_message = "captf_contract must be \"v1alpha1\": this module implements contract v1alpha1 only."
  }
}

# Names come from machinepool_name and the cluster's exports.
# tflint-ignore: terraform_unused_declarations
variable "captf_cluster" {
  description = "The owning CAPI Cluster: name and namespace (common.md \"Inputs\")."
  type = object({
    name      = string
    namespace = string
  })
}

# The TerraformMachinePool reaches Azure through captf_tags.
# tflint-ignore: terraform_unused_declarations
variable "captf_object" {
  description = "The TerraformMachinePool being reconciled (common.md \"Inputs\")."
  type = object({
    kind      = string
    name      = string
    namespace = string
  })
}

variable "captf_cluster_outputs" {
  description = "The cluster role's exports (schema captf.io/azure-cluster/v1), or {} for an externally managed TerraformCluster (common.md \"captf_cluster_outputs\")."
  type        = any

  validation {
    condition     = try(length(keys(var.captf_cluster_outputs)) == 0, false) || try(var.captf_cluster_outputs.schema == "captf.io/azure-cluster/v1", false)
    error_message = "captf_cluster_outputs must be the exports of the CAPTF Azure cluster module (schema captf.io/azure-cluster/v1) or {}: use an azure-cluster image of a compatible version for the TerraformCluster."
  }
}

variable "captf_tags" {
  description = "Tags the controller sets on every object (common.md \"captf_tags\"); applied to every taggable resource through local.tags."
  type        = map(string)
}

variable "machinepool_name" {
  description = "The owning CAPI MachinePool's name; the scale set and its instances' hostnames are named after it (machinepool.md \"Inputs\")."
  type        = string
}

variable "replicas" {
  description = "Desired capacity of the scale set (machinepool.md \"replicas (input)\")."
  type        = number

  validation {
    # A uniform scale set without a single placement group holds 1000 VMs
    # (https://learn.microsoft.com/azure/virtual-machine-scale-sets/virtual-machine-scale-sets-placement-groups).
    condition     = var.replicas == floor(var.replicas) && var.replicas >= 0 && var.replicas <= 1000
    error_message = "replicas must be a whole number from 0 to 1000, the size limit of an Azure scale set."
  }
}

variable "bootstrap_data" {
  description = "Base64 of the bootstrap Secret's value (machinepool.md \"bootstrap_data (input)\"). Passed on as custom data, never decoded."
  type        = string
  sensitive   = true
}

variable "bootstrap_format" {
  description = "Format of the bootstrap payload: cloud-config or ignition (machine.md \"bootstrap_format\")."
  type        = string

  validation {
    condition     = contains(["cloud-config", "ignition"], var.bootstrap_format)
    error_message = "bootstrap_format must be cloud-config or ignition."
  }
}

variable "failure_domains" {
  description = "MachinePool.spec.failureDomains: the availability zones to spread over; [] uses cluster_failure_domains (machinepool.md \"failure_domains (input)\"). A change replaces the scale set."
  type        = list(string)
}

variable "cluster_failure_domains" {
  description = "The cluster's failure domains, which are its zones (machinepool.md \"cluster_failure_domains (input)\")."
  type        = list(string)
}

variable "kubernetes_version" {
  description = "MachinePool.spec.template.spec.version, possibly with a +suffix (machinepool.md \"kubernetes_version (input)\"). A change rolls the pool; it also fills {version} and {semver} in image_id."
  type        = string
  default     = null
}

variable "node_labels" {
  description = "MachinePool.spec.template.metadata.labels, registered by the kubelet (machinepool.md \"node_labels (input)\"). Labels the NodeRestriction admission plugin forbids are dropped."
  type        = map(string)

  validation {
    # Kubernetes label syntax (https://kubernetes.io/docs/concepts/overview/working-with-objects/labels/#syntax-and-character-set).
    # The API server already enforces it; checking again keeps every label
    # safe to write into the boothook's shell and YAML.
    condition = alltrue([
      for k, v in var.node_labels :
      can(regex("^([a-z0-9]([-a-z0-9]*[a-z0-9])?(\\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*/)?[A-Za-z0-9]([-A-Za-z0-9_.]{0,61}[A-Za-z0-9])?$", k)) &&
      can(regex("^(([A-Za-z0-9][-A-Za-z0-9_.]{0,61})?[A-Za-z0-9])?$", v))
    ])
    error_message = "node_labels must hold Kubernetes label keys and values."
  }
}

variable "autoscaling" {
  description = "The MachinePool's autoscaler annotations, parsed (machinepool.md \"autoscaling (input)\"). Enabled: the scale set scales between min and max, on CPU through Azure Autoscale (autoscaler native) or by a scaler outside the module (autoscaler external)."
  type = object({
    enabled = bool
    min     = number
    max     = number
  })

  validation {
    condition     = !var.autoscaling.enabled || (var.autoscaling.min >= 0 && var.autoscaling.min <= var.autoscaling.max && var.autoscaling.max <= 1000)
    error_message = "autoscaling needs 0 <= min <= max <= 1000: Azure Autoscale and a scale set allow at most 1000 instances."
  }
}
