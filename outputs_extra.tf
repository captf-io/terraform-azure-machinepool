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

# Non-contract outputs, alphabetical. The controller never reads them; they
# help when inspecting a pool's state.

output "autoscale_setting_id" {
  description = "ARM ID of the Azure Autoscale setting that holds the capacity; null while autoscaling is enabled with autoscaler external."
  value       = one(azurerm_monitor_autoscale_setting.pool_autoscale_setting[*].id)
}

output "dropped_node_labels" {
  description = "node_labels keys left out because the kubelet may not set them on itself (NodeRestriction; CONVENTIONS.md section 13)."
  value       = local.dropped_node_labels
}

output "scale_set_id" {
  description = "ARM ID of the current scale set."
  value       = one(azurerm_linux_virtual_machine_scale_set.pool_scale_set[*].id)
}

output "scale_set_name" {
  description = "Name of the current scale set; a new generation has a new name."
  value       = one(azurerm_linux_virtual_machine_scale_set.pool_scale_set[*].name)
}
