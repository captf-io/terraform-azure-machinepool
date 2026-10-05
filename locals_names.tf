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

# Names of the pool's Azure resources (CONVENTIONS.md section 6). The scale
# set name, which is also its instances' hostname prefix, carries a hash of
# everything that cannot change in place: a change makes a new scale set
# that create_before_destroy brings up before the old one goes
# (DESIGN.md decision 7; README "Limitations").
locals {
  # What azurerm 5.7.0 cannot update on a scale set (ForceNew, or zones that
  # may only grow), plus the Kubernetes version verbatim, which must roll the
  # pool, a +rke2rN bump included (machinepool.md "Lifecycle"; CONVENTIONS.md
  # section 13). Only explicit failure domains count: zones inherited from
  # the cluster are pinned at the first apply (pool_default_zones.tf).
  scale_set_generation = jsonencode({
    failure_domains              = sort(var.failure_domains)
    kubernetes_version           = var.kubernetes_version
    os_disk_storage_account_type = var.os_disk_storage_account_type
    spot                         = var.spot
    trusted_launch               = var.trusted_launch
  })
  # A Linux hostname prefix allows 58 characters and gets 6 more per
  # instance; 41 + "-" + 8 hex keeps the name at 50, unique per pool and
  # generation, and a valid DNS label.
  scale_set_name = "${trimsuffix(substr(replace(lower(var.machinepool_name), "/[^a-z0-9-]/", "-"), 0, 41), "-")}-${substr(sha256("${var.machinepool_name}/${local.scale_set_generation}"), 0, 8)}"

  autoscale_setting_name = "${local.scale_set_name}-autoscale"
  network_interface_name = "primary"
}
