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

# Whether the scale set exists, without failing when it does not: an empty
# list on a missing scale set, where data.azurerm_virtual_machine_scale_set
# errors. Subscription-wide, filtered to the cluster's group in
# locals_health.tf: a listing scoped to a deleted resource group fails with
# ResourceGroupNotFound, which would block every destroy. It references no
# resource, so its result, and the member read's count, are known at plan
# time (DESIGN.md decision 7).
data "azurerm_resources" "pool_scale_set_listing" {
  name = local.scale_set_name
  type = "Microsoft.Compute/virtualMachineScaleSets"

  lifecycle {
    # Checked here because, without exports, the scale set has count 0.
    precondition {
      condition     = local.exports_available
      error_message = "The TerraformCluster is externally managed (captf_cluster_outputs is {}): set spec.variables.external_cluster_exports to the exports of the cluster this pool joins (README \"Exports\")."
    }
  }
}
