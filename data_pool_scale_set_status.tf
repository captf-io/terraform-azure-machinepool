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

# The scale set's instances with their power states and addresses, read on
# every refresh (paged, never truncated), and only when the listing found
# the scale set (locals_health.tf).
data "azurerm_virtual_machine_scale_set" "pool_scale_set_status" {
  count = local.exports_available && local.scale_set_listed ? 1 : 0

  name                = local.scale_set_name
  resource_group_name = local.resource_group_name
}
