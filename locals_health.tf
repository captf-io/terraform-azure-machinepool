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

# Membership and health of the pool (CONVENTIONS.md section 10;
# machinepool.md "Per-instance state"). Members come from
# data.azurerm_virtual_machine_scale_set, read only when the resource
# listing finds the scale set, because that data source fails on a missing
# one and would fail every refresh and destroy.
locals {
  scale_set_exists = one(azurerm_linux_virtual_machine_scale_set.pool_scale_set[*].id) != null
  listed_scale_sets = [
    for r in data.azurerm_resources.pool_scale_set_listing.resources : r
    if lower(r.resource_group_name) == lower(coalesce(local.resource_group_name, "-"))
  ]
  scale_set_listed = length(local.listed_scale_sets) > 0
  # The observed desired capacity: refreshed from Azure, which Azure
  # Autoscale or an outside scaler changes (ignore_changes keeps applies
  # from resetting it).
  observed_replicas = one(azurerm_linux_virtual_machine_scale_set.pool_scale_set[*].instances)

  # Azure lists an instance until it is deleted, and an instance being
  # deleted has no state of its own here, so no member maps to terminated:
  # a deleted instance simply leaves the list (and CAPI deletes its Node).
  members = try(data.azurerm_virtual_machine_scale_set.pool_scale_set_status[0].instances, [])

  # Azure VM power state -> contract health ("health" in common.md;
  # https://learn.microsoft.com/azure/virtual-machines/states-billing).
  health_by_state = {
    running      = { state = "running", reason = null }
    starting     = { state = "pending", reason = "PowerState/starting" }
    ""           = { state = "pending", reason = "PowerState/unknown" } # no power state yet: still creating
    stopping     = { state = "stopped", reason = "PowerState/stopping" }
    stopped      = { state = "stopped", reason = "PowerState/stopped" }
    deallocating = { state = "stopped", reason = "PowerState/deallocating" }
    deallocated  = { state = "stopped", reason = "PowerState/deallocated" }
  }
  instance_details = [
    for m in local.members : {
      provider_id    = "azure:///subscriptions/${lower(coalesce(local.subscription_id, "-"))}/resourceGroups/${lower(coalesce(local.resource_group_name, "-"))}/providers/Microsoft.Compute/virtualMachineScaleSets/${local.scale_set_name}/virtualMachines/${m.instance_id}"
      instance_id    = m.instance_id
      name           = m.computer_name
      state          = lookup(local.health_by_state, m.power_state == null ? "" : lower(m.power_state), { state = "unknown", reason = "UnknownState" }).state
      reason         = lookup(local.health_by_state, m.power_state == null ? "" : lower(m.power_state), { state = "unknown", reason = "UnknownState" }).reason
      failure_domain = m.zone == "" ? null : m.zone
      addresses = [
        for a in [{ type = "InternalIP", address = m.private_ip_address }, { type = "Hostname", address = m.computer_name }] : a
        if a.address != null && a.address != ""
      ]
    }
  ]

  instances_by_provider_id = { for i in local.instance_details : i.provider_id => i }

  # CONVENTIONS.md section 10, in order: the scale set gone, capacity 0, no
  # members yet, the worst of degraded, stopped and unknown members, then
  # running, healthy only at capacity with every member running. Starting
  # members never make the pool pending (machinepool.md "Deriving group
  # health"); they are named, and a count mismatch adds ScalingInProgress.
  worst_state       = [for s in ["degraded", "stopped", "unknown"] : s if contains(local.instance_details[*].state, s)]
  affected_reasons  = sort([for i in local.instance_details : "${i.reason}:${i.name}" if i.state != "running"])
  members_converged = length(local.instance_details) == coalesce(local.observed_replicas, -1)

  health_reading = (
    # Deleted out of band: the refresh dropped the scale set from the state.
    !local.scale_set_exists ? { state = "terminated", healthy = false, message = "Azure scale set ${local.scale_set_name} not found", reasons = ["ScaleSetNotFound"] } :
    local.observed_replicas == 0 ? { state = "running", healthy = true, message = null, reasons = [] } :
    # Created by this apply (or by a version roll), or ARM's listing has not
    # caught up: the next refresh reads the members.
    !local.scale_set_listed || length(local.instance_details) == 0 ? { state = "pending", healthy = false, message = "Azure scale set ${local.scale_set_name} has no members yet", reasons = ["NoMembers"] } :
    length(local.worst_state) > 0 ? {
      state   = local.worst_state[0]
      healthy = false
      message = "${length(local.affected_reasons)} of ${length(local.instance_details)} instances not running"
      reasons = local.affected_reasons
    } :
    {
      state   = "running"
      healthy = length(local.affected_reasons) == 0 && local.members_converged
      message = length(local.affected_reasons) == 0 && local.members_converged ? null : "${length(local.instance_details)} of ${local.observed_replicas} instances, ${length(local.affected_reasons)} starting"
      reasons = concat(local.affected_reasons, local.members_converged ? [] : ["ScalingInProgress"])
    }
  )
}
