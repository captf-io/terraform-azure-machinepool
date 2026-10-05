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

# Contract outputs of the machinepool role, v1alpha1, in contract order
# (https://captf.io/docs/module-author/contract/v1alpha1/machinepool.html#outputs
# and common.html#outputs). try(): a scale set deleted out of band leaves
# the state on refresh, and the refresh must not fail on it.

output "provider_id" {
  description = "azure:///<scale set ARM ID, lowercase resource group>; changes when a version change replaces the scale set (machinepool.md \"provider_id (output)\")."
  value       = try("azure:///subscriptions/${lower(local.subscription_id)}/resourceGroups/${lower(local.resource_group_name)}/providers/Microsoft.Compute/virtualMachineScaleSets/${azurerm_linux_virtual_machine_scale_set.pool_scale_set[0].name}", null)
}

output "provider_id_list" {
  description = "Every instance the scale set lists, whatever its power state, as cloud-provider-azure writes Node.spec.providerID (machinepool.md \"provider_id_list (output)\"; README \"provider_id\")."
  value       = sort(keys(local.instances_by_provider_id))
}

output "replicas" {
  description = "The scale set's capacity as last refreshed, which Azure Autoscale sets (machinepool.md \"replicas (output)\")."
  value       = local.observed_replicas
}

output "instances" {
  description = "One entry per instance: provider ID, instance ID, addresses, zone and health state (machinepool.md \"instances (output)\")."
  value = [
    for id in sort(keys(local.instances_by_provider_id)) : {
      provider_id    = id
      instance_id    = local.instances_by_provider_id[id].instance_id
      addresses      = local.instances_by_provider_id[id].addresses
      failure_domain = local.instances_by_provider_id[id].failure_domain
      state          = local.instances_by_provider_id[id].state
    }
  ]
}

output "health" {
  description = "Health from the instances' power states (common.md \"Outputs\"; README \"Health\")."
  value       = local.health_reading
}
