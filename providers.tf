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

# The azurerm provider for the machinepool role. Credentials come from the
# identity Secret's ARM_* environment variables; the subscription is the
# cluster's, from exports.
provider "azurerm" {
  # Registration is a prerequisite (README "Prerequisites").
  resource_provider_registrations = "none"
  # Null (an externally managed cluster without external_cluster_exports)
  # falls back to ARM_SUBSCRIPTION_ID; the precondition on the scale set
  # listing then fails with the actionable message.
  subscription_id = local.subscription_id

  features {
    virtual_machine_scale_set {
      # Load-bearing. A custom_data change, which every bootstrap token
      # rotation is (about every 7.5 minutes), marks the instances for update;
      # with the provider defaults (true, true) azurerm 5.7.0 then updates and
      # reimages every instance (virtual_machine_scale_set_update.go
      # performUpdate). False updates the scale set model only, so new
      # instances get the new data and running ones are left alone
      # (machinepool.md "Bootstrap rotation"; DESIGN.md decision 7).
      reimage_on_manual_upgrade    = false
      roll_instances_when_required = false
      # Delete instances one by one through the scale set before deleting it,
      # and never force-delete (the provider defaults, set for the reader).
      force_delete                  = false
      scale_to_zero_before_deletion = true
    }
  }
}
